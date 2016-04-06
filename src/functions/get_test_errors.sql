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