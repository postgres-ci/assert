create or replace function assert.get_current_test_id() returns int as $$
    begin 
        return (
            SELECT test_id FROM assert.current_test_id WHERE current_test = currval('assert.current_test')
        );
    end;
$$ language plpgsql security definer;