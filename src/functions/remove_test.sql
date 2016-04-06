create or replace function assert.remove_test(_test_id int) returns void as $$
    begin 
        DELETE FROM assert.tests WHERE test_id = _test_id;
    end;
$$ language plpgsql security definer;