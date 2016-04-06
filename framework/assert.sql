-- The PLpgSQL Unit Testing framework
-- Do not edit this file manually!

    /* src/assert.sql */
	
create schema assert;

create sequence assert.current_test;
create sequence assert.running_numbers;

create table assert.tests (
    test_id     serial  primary key,
    namespace   name    not null,
    procedure   name    not null check(procedure like 'test\_%'),
    created_at  timestamptz not null default current_timestamp
);

create unique index uidx_assert_test_func on assert.tests (lower(namespace || '.' || procedure));

create type assert.error as (
    message  text,
    comment  text,
    context  text
);

create unlogged table assert.errors(
    test_id  int          not null references assert.tests(test_id) on delete cascade,
    run_num  bigint       not null default currval('assert.running_numbers'),
    error    assert.error not null
);

create unlogged table assert.current_test_id(
    current_test int not null default currval('assert.current_test') primary key,
    test_id      int not null references assert.tests(test_id) on delete cascade
);

create table assert.results(
    test_id     int            not null references assert.tests(test_id) on delete cascade,
    run_num     bigint         not null default currval('assert.running_numbers'),
    errors      assert.error[] not null default '{}',
    started_at  timestamptz    not null,
    finished_at timestamptz,
    primary key (run_num, test_id)
);

create index idx_assert_test_results on assert.results(test_id);

create or replace view assert.view_tests as 
    SELECT 
        T.test_id,
        T.namespace,
        T.procedure,
        T.created_at,
        R.started_at AS last_run_at,
        CASE 
            WHEN R.test_id IS NULL THEN '-'
            WHEN array_length(r.errors, 1) IS NULL THEN 'PASS'
            ELSE 'FAIL' 
        END AS last_result
    FROM assert.tests AS T 
    LEFT JOIN LATERAL (
        SELECT 
            R.test_id,
            R.errors, 
            R.started_at 
        FROM assert.results AS R 
        WHERE R.test_id = T.test_id 
        ORDER BY R.run_num DESC 
        LIMIT 1
    ) AS R USING(test_id);

    /* src/functions/add_test.sql */
	
create or replace function assert.add_test(_namespace name, _procedure name) returns void as $$
    begin 
        INSERT INTO assert.tests (namespace, procedure) VALUES (_namespace, _procedure);
    end;
$$ language plpgsql security definer;
    /* src/functions/fail.sql */
	
create or replace function assert.fail(
    _message text, 
    _comment text, 
    _context text
) returns boolean as $$
    declare 
        _current_test_id int;
    begin 

        _current_test_id = assert.get_current_test_id();

        IF _current_test_id IS NULL THEN 

            RAISE EXCEPTION '%', (
                SELECT
                    CASE WHEN _comment != '' THEN
                        _message || '. ' || _comment
                    ELSE _message END
            );

        END IF;

        INSERT INTO assert.errors (
            test_id,
            error 
        ) VALUES (
            _current_test_id,
            (_message, _comment, _context)::assert.error
        );

        return false;
    end;
$$ language plpgsql security definer;
    /* src/functions/finish_test.sql */
	
create or replace function assert.finish_test(_errors assert.error[]) returns void as $$
    begin 
    
        UPDATE assert.results
            SET
                errors      = _errors,
                finished_at = clock_timestamp()
        WHERE test_id = assert.get_current_test_id()
        AND   run_num = currval('assert.running_numbers');

        DELETE FROM assert.current_test_id WHERE current_test = currval('assert.current_test');
    end;
$$ language plpgsql security definer;
    /* src/functions/get_current_test_id.sql */
	
create or replace function assert.get_current_test_id() returns int as $$
    begin 
        return (
            SELECT test_id FROM assert.current_test_id WHERE current_test = currval('assert.current_test')
        );
    end;
$$ language plpgsql security definer;
    /* src/functions/get_test_errors.sql */
	
create or replace function assert.get_test_errors() returns assert.error[] as $$
    begin
        return (
            SELECT
                COALESCE(array_agg(E.error), '{}')
            FROM assert.errors AS E
            WHERE test_id  = assert.get_current_test_id() 
            AND   run_num  = currval('assert.running_numbers')
        );
    end;
$$ language plpgsql security definer;
    /* src/functions/remove_test.sql */
	
create or replace function assert.remove_test(_test_id int) returns void as $$
    begin 
        DELETE FROM assert.tests WHERE test_id = _test_id;
    end;
$$ language plpgsql security definer;
    /* src/functions/start_test.sql */
	
create or replace function assert.start_test(_test_id int) returns void as $$
    begin 

        PERFORM nextval('assert.current_test');
        
        INSERT INTO assert.results (
            test_id,
            started_at
        ) VALUES (
            _test_id,
            clock_timestamp()
        );

        INSERT INTO assert.current_test_id (test_id) VALUES (_test_id);
    end;
$$ language plpgsql security definer;
    /* src/functions/test_runner.sql */
	
create or replace function assert.test_runner() returns table (
    namespace   name,
    procedure   name,
    errors      assert.error[],
    started_at  timestamptz,
    finished_at timestamptz
) as $$
    declare
        _test_id     int;
        _test_func   text;
        _test_errors assert.error[];
    begin 

        PERFORM nextval('assert.running_numbers');

        FOR _test_id, _test_func IN 
            SELECT 
                T.test_id, 
                quote_ident(T.namespace) || '.' || quote_ident(T.procedure) AS func 
            FROM assert.tests AS T
            ORDER BY T.test_id
        LOOP
            
            PERFORM assert.start_test(_test_id);

            BEGIN

                EXECUTE 'SELECT ' || _test_func || '()';

                _test_errors = assert.get_test_errors();

                RAISE EXCEPTION 'ROLLBACK_INNER_TRANSACTION';

            EXCEPTION WHEN OTHERS THEN

                IF SQLERRM <> 'ROLLBACK_INNER_TRANSACTION' THEN

                    _test_errors = array_append(_test_errors, (
                            format('Uncaught exception "%s" in "%s"', SQLERRM, _test_func), 
                            '', 
                            ''
                        )::assert.error
                    );

                END IF;
            END;

            PERFORM assert.finish_test(_test_errors);

        END LOOP;

        return query 
            SELECT 
                T.namespace,
                T.procedure,
                R.errors,
                R.started_at,
                R.finished_at
            FROM assert.tests   AS T
            JOIN assert.results AS R USING(test_id)
            WHERE R.run_num = currval('assert.running_numbers')
            ORDER BY T.namespace, T.procedure;

    end;
$$ language plpgsql security definer;

    /* src/assertions/equal.sql */
	
create or replace function assert.equal(_expected anyelement, _actual anyelement, _comment text default '') returns boolean as $$
    declare
        _context text;
    begin

        IF _expected != _actual THEN

            GET DIAGNOSTICS _context = PG_CONTEXT;

            return assert.fail(format('Not equal: %s (expected) != %s (actual)', _expected, _actual), _comment, _context);
        END IF;

        return true;
    end;
$$ language plpgsql security definer;
    /* src/grants.sql */
	
grant  usage   on schema assert to public;
revoke execute on all functions in schema assert from public;
grant execute on function assert.add_test(name, name) to public;
grant execute on function assert.remove_test(int) to public;
grant execute on function assert.test_runner() to public;
grant execute on function assert.equal(anyelement, anyelement, text) to public;
grant select on table assert.view_tests to public;