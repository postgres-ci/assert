
\echo Use "CREATE EXTENSION assert" to load this file. \quit

set statement_timeout     = 0;
set client_encoding       = 'UTF8';
set client_min_messages   = warning;
set escape_string_warning = off;
set standard_conforming_strings = on;



    /* src/assert.sql */
	
create table assert.tests(
    test_id    serial not null primary key,
    test_func  varchar not null check (test_func LIKE '%Test%'),
    is_running boolean not null default false,
    created_at timestamptz not null default current_timestamp
);

create index idx_test_like on assert.tests using gin (test_func gin_trgm_ops);
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
    declare
        _result assert.test_errors;
        _errors assert.test_error[] default '{}';
    begin

        FOR _result IN SELECT * FROM assert.test_errors WHERE test_id = _test_id AND test_seq  = currval('assert.test_seq') LOOP
            _errors = array_append(_errors, ROW(
                    _result.error,
                    _result.description,
                    _result.context
                )::assert.test_error
            );
        END LOOP;

        return _errors;
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
                    RAISE EXCEPTION '%', SQLERRM;
                END IF;
            END;

            PERFORM assert.end_test(_test_id, _test_errors);

            IF array_length(_test_errors, 1) IS NOT NULL THEN
            --    EXIT;
            END IF;

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

    /* src/assertions/equal.sql */
	
create or replace function assert.Equal(_expected anyelement, _actual anyelement, _description text default '') returns boolean as $$
    declare
        _context text;
    begin

        GET DIAGNOSTICS _context = PG_CONTEXT;

        IF _expected != _actual THEN
            return assert.Fail(format('Not equal: %s (expected) != %s (actual)', _expected, _actual), _description, _context);
        END IF;

        return true;
    end;
$$ language plpgsql;

    /* src/assertions/exception.sql */
	
create or replace function assert.Exception(_sql text, _exception_message text default '', _exception_code text default '', _description text default '') returns boolean as $$
    declare
        _context text;
    begin

        GET DIAGNOSTICS _context = PG_CONTEXT;

        BEGIN
            EXECUTE _sql;
        EXCEPTION WHEN OTHERS THEN

            IF _exception_message != '' AND SQLERRM NOT LIKE _exception_message THEN
                return assert.Fail(format('Exception message not equal: %s (expected) != %s (actual)', _exception_message, SQLERRM), _description, _context);
            END IF;

            IF _exception_code != '' AND _exception_code != SQLSTATE THEN
                return assert.Fail(format('Exception code not equal: %s (expected) != %s (actual)', _exception_code, SQLSTATE), _description, _context);
            END IF;

            return true;
        END;

        return assert.Fail('No exception thrown', _description, _context);
    end;
$$ language plpgsql;

    /* src/assertions/false.sql */
	
create or replace function assert.False(_value boolean, _description text default '') returns boolean as $$
    declare
        _context text;
    begin

        GET DIAGNOSTICS _context = PG_CONTEXT;

        IF _value IS NOT FALSE THEN
            return assert.Fail('Should be false', _description, _context);
        END if;

        return true;
    end;
$$ language plpgsql;

    /* src/assertions/len.sql */
	
create or replace function assert.Len(_array anyarray, _length int, _description text default '') returns boolean as $$
    declare
        _context text;
    begin

        GET DIAGNOSTICS _context = PG_CONTEXT;

        IF array_length(_array, 1) != _length THEN
            return assert.Fail(format('"%s" should have %s item(s), but has %s', _array, _length, COALESCE(array_length(_array, 1), 0)), _description, _context);
        END IF;

        return true;
    end;

$$ language plpgsql;

    /* src/assertions/not_equal.sql */
	
create or replace function assert.NotEqual(_expected anyelement, _actual anyelement, _description text default '') returns boolean as $$
    declare
        _context text;
    begin

        GET DIAGNOSTICS _context = PG_CONTEXT;

        IF _expected = _actual THEN
            return assert.Fail(format('Should not be: %s', _actual), _description, _context);
        END IF;

        return true;
    end;
$$ language plpgsql;

    /* src/assertions/not_null.sql */
	
create or replace function assert.NotNull(_object anyelement, _description text default '') returns boolean as $$
    begin
        return true;
    end;
$$ language plpgsql;

create or replace function assert.NotNull(_object text, _description text default '') returns boolean as $$
    declare
        _context text;
    begin

        GET DIAGNOSTICS _context = PG_CONTEXT;

        IF _object IS NULL THEN
            return assert.Fail('Expected value not to be null.', _description, _context);
        END if;

        return true;
    end;
$$ language plpgsql;

    /* src/assertions/null.sql */
	
create or replace function assert.Null(_object anyelement, _description text default '') returns boolean as $$
    declare
        _context text;
    begin

        GET DIAGNOSTICS _context = PG_CONTEXT;

        IF _object IS NOT NULL THEN
            return assert.Fail(format('Expected null, but got: %s', _object), _description, _context);
        END if;

        return true;
    end;
$$ language plpgsql;


create or replace function assert.Null(_object text, _description text default '') returns boolean as $$
    declare
        _context text;
    begin

        GET DIAGNOSTICS _context = PG_CONTEXT;

        IF _object IS NOT NULL THEN
            return assert.Fail(format('Expected null, but got: %s', _object), _description, _context);
        END if;

        return true;
    end;
$$ language plpgsql;

    /* src/assertions/true.sql */
	
create or replace function assert.True(_value boolean, _description text default '') returns boolean as $$
    declare
        _context text;
    begin

        GET DIAGNOSTICS _context = PG_CONTEXT;

        IF _value IS NOT TRUE THEN
            return assert.Fail('Should be true', _description, _context);
        END if;

        return true;
    end;
$$ language plpgsql;
