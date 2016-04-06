create schema example;

create table example.users(
    user_id   serial primary key,
    user_name varchar not null
);

create or replace function example.create_user(_user_name varchar, out id int) returns int as $$
    begin 

        INSERT INTO example.users (user_name) VALUES (_user_name) RETURNING user_id INTO id;
    end;
$$ language plpgsql;

insert into example.users (user_name) select 'user_name_' || u::varchar from generate_series(1, 100) as u;