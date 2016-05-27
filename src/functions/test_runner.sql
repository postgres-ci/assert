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
            
            PERFORM assert.begin_test(_test_id);

            BEGIN

                EXECUTE 'SELECT ' || _test_func || '()';

                _test_errors = assert.get_test_errors();

                RAISE EXCEPTION 'ROLLBACK_INNER_TRANSACTION';

            EXCEPTION WHEN OTHERS THEN

                IF SQLERRM <> 'ROLLBACK_INNER_TRANSACTION' THEN

                    _test_errors = array_append(_test_errors, (
                            format('Uncaught exception "%s" in "%s"', SQLERRM, _test_func), 
                            ''
                        )::assert.error
                    );

                END IF;
            END;

            PERFORM assert.end_test(_test_errors);

            _test_errors = '{}';

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
