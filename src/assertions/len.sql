create or replace function assert.Len(_array anyarray, _length int, _description text default '') returns boolean as $$
    declare
        _context text;
    begin

        GET DIAGNOSTICS _context = PG_CONTEXT;

        IF array_length(_array, 1) != _length THEN
            return assert.Fail(format('"%s" should have %s item(s), but has %s', _array, _length, COALESCE(array_length(_array, 1), 0)), _description, _context);
        END IF;

        return true;
    end;

$$ language plpgsql;
