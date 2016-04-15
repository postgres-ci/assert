create schema example;

create table example.users(
    user_id    serial primary key,
    user_name  varchar not null,
    user_email varchar not null,
    constraint check_user_email check(strpos(user_email, '@') > 0),
    constraint unique_user_name unique(user_name),
    constraint unique_user_email unique(user_email)
);

create or replace function example.create_user(_user_name varchar, _user_email varchar, out id int) returns int as $$
    begin 

        INSERT INTO example.users (user_name, user_email) VALUES (_user_name, _user_email) RETURNING user_id INTO id;
    end;
$$ language plpgsql;

create or replace function example.uncovered() returns void as $$
$$ language sql;
