create table assert.tests(
    test_id    serial not null primary key,
    test_func  varchar not null check (test_func LIKE '%Test%'),
    is_running boolean not null default false,
    created_at timestamptz not null default current_timestamp
);

create unique index uidx_test_func  on assert.tests (lower(test_func));
create unique index uidx_is_running on assert.tests (is_running) where is_running = true;

create sequence assert.test_seq;

create type assert.test_error as (
    error       text,
    description text,
    context     text
);

create table assert.test_results (
    test_seq   bigint not null,
    test_id    int not null references assert.tests(test_id),
    errors     assert.test_error[] not null default '{}',
    started_at timestamptz not null,
    stopped_at timestamptz,
    primary key (test_seq, test_id)
);

create unlogged table assert.test_errors(
    test_seq     bigint not null,
    test_id      int not null references assert.tests(test_id),
    error        text,
    description  text,
    context      text
);

create or replace function assert.begin_test(_test_id int) returns void as $$
    begin
        UPDATE assert.tests SET is_running = true  WHERE test_id = _test_id;
        INSERT INTO assert.test_results (
            test_seq,
            test_id,
            started_at
        ) VALUES (
            currval('assert.test_seq'),
            _test_id,
            clock_timestamp()
        );
    end;
$$ language plpgsql;

create or replace function assert.end_test(_test_id int, _errors assert.test_error[]) returns void as $$
    begin
        UPDATE assert.tests SET is_running = false  WHERE test_id = _test_id;
        UPDATE assert.test_results
            SET
                errors     = _errors,
                stopped_at = clock_timestamp()
        WHERE test_id = _test_id
        AND test_seq  = currval('assert.test_seq');
    end;
$$ language plpgsql;

create or replace function assert.get_test_errors(_test_id int) returns assert.test_error[] as $$
    begin
        return (
            SELECT
                COALESCE(array_agg(ROW(error, description, context)::assert.test_error), '{}')
            FROM assert.test_errors
            WHERE test_id = _test_id AND test_seq  = currval('assert.test_seq')
        );
    end;
$$ language plpgsql;

create or replace function assert.Fail(_error text, _description text, _context text) returns boolean as $$
    declare
        _current_test_id bigint;
    begin

        SELECT test_id INTO _current_test_id FROM assert.tests WHERE is_running = true;

        IF NOT FOUND THEN

            RAISE EXCEPTION '%', (
                SELECT
                    CASE WHEN _description != '' THEN
                        _error || '. ' || _description
                    ELSE _error END
            );

        ELSE

            INSERT INTO assert.test_errors (
                test_id,
                test_seq,
                error,
                description,
                context
            ) VALUES (
                _current_test_id,
                currval('assert.test_seq'),
                _error,
                _description,
                _context
            );

        END IF;

        return false;
    end;
$$ language plpgsql;

create or replace function assert.RunTests(_pattern text default '') returns bigint as $$
    declare
        _test_id     int;
        _test_func   varchar;
        _test_errors assert.test_error[];

        _message           text;
        _exception_context text;
    begin

        LOCK TABLE assert.tests IN ACCESS EXCLUSIVE MODE;

        PERFORM nextval('assert.test_seq');

        FOR _test_id, _test_func IN
            SELECT
                test_id,
                test_func
            FROM assert.tests
            WHERE CASE
                WHEN _pattern <> '' THEN
                    test_func LIKE _pattern
                ELSE true
            END
            ORDER BY test_func
        LOOP
            PERFORM assert.begin_test(_test_id);

            BEGIN

                EXECUTE 'SELECT ' || _test_func || '()';

                _test_errors = assert.get_test_errors(_test_id);

                RAISE EXCEPTION 'ROLLBACK_INNER_TRANSACTION';

            EXCEPTION WHEN OTHERS THEN
                IF SQLERRM <> 'ROLLBACK_INNER_TRANSACTION' THEN

                    GET STACKED DIAGNOSTICS
                        _message           = MESSAGE_TEXT,
                        _exception_context = PG_EXCEPTION_CONTEXT;

                    _test_errors = array_append(_test_errors, ROW(format('Uncaught exception "%s" in "%s"', _message, _test_func), '', _exception_context)::assert.test_error);

                END IF;
            END;

            PERFORM assert.end_test(_test_id, _test_errors);
/*
            IF array_length(_test_errors, 1) IS NOT NULL THEN
               EXIT;
            END IF;
*/
        END LOOP;

        return currval('assert.test_seq');
    end;
$$ language plpgsql;


create or replace function assert.TestRunner() returns table (
    test   varchar,
    result varchar,
    errors jsonb,
    "time" interval
) as $$
    declare
        _test_seq bigint;
    begin

        _test_seq = assert.RunTests();

        return query
        SELECT
            T.test_func::varchar,
            CASE WHEN array_length(R.errors, 1) IS NULL THEN
                'PASS'::varchar
            ELSE
                'FAIL'::varchar
            END AS result,
            to_json(R.errors)::jsonb AS errors,
            R.stopped_at - R.started_at AS time
        FROM assert.test_results AS R
        JOIN assert.tests        AS T USING (test_id)
        WHERE R.test_seq = _test_seq;

    end;
$$ language plpgsql;
