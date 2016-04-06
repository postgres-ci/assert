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