create or replace function assert.true(_value boolean, _comment text default '') returns boolean as $$
    begin

        IF _value IS NOT TRUE THEN
            return assert.fail('Should be true', _comment);
        END if;

        return true;
    end;
$$ language plpgsql security definer;