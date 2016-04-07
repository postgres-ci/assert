create or replace function assert.false(_value boolean, _comment text default '') returns boolean as $$
    begin

        IF _value IS NOT FALSE THEN
            return assert.fail('Should be false', _comment);
        END if;

        return true;
    end;
$$ language plpgsql security definer;