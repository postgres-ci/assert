create or replace function assert.finish_test(_test_id int, _errors assert.error[]) returns void as $$
    begin 

        UPDATE assert.tests SET is_running = false  WHERE test_id = _test_id;

        UPDATE assert.results
            SET
                errors      = _errors,
                finished_at = clock_timestamp()
        WHERE test_id = _test_id
        AND   run_num  = currval('assert.running_numbers');
    end;
$$ language plpgsql security definer;