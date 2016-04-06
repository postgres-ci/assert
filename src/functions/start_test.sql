create or replace function assert.start_test(_test_id int) returns void as $$
    begin 

        UPDATE assert.tests SET is_running = true  WHERE test_id = _test_id;
        
        INSERT INTO assert.results (
            test_id,
            started_at
        ) VALUES (
            _test_id,
            clock_timestamp()
        );
    end;
$$ language plpgsql security definer;