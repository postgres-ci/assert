create or replace function assert.get_current_test_id() returns int as $$
    begin 
        return (
            SELECT test_id FROM assert.tests WHERE is_running = true
        );
    end;
$$ language plpgsql security definer;