BEGIN;

-- Identifiers are supplied when inserting rows; they are not generated automatically.
-- All foreign keys use ON DELETE RESTRICT to prevent deleting referenced rows.

-- 1. Tables with no dependencies on other tables.
-- Pending rule: assign country numbers consecutively in alphabetical order.
CREATE TABLE country (
    country_number INTEGER PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    club_count INTEGER NOT NULL,
    -- NULL means no representative; several countries may share the same one.
    representative_country_number INTEGER,

    CONSTRAINT ck_country_number
        CHECK (country_number > 0),

    CONSTRAINT ck_country_club_count
        CHECK (club_count >= 0),

    CONSTRAINT ck_country_representative
        CHECK (representative_country_number IS NULL OR representative_country_number <> country_number),

    CONSTRAINT fk_country_representative
        FOREIGN KEY (representative_country_number)
        REFERENCES country (country_number)
        ON DELETE RESTRICT
);
CREATE TABLE hotel (
    hotel_id INTEGER PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    address VARCHAR(250) NOT NULL,
    phone_number VARCHAR(30) NOT NULL
);
CREATE TABLE tournament (
    tournament_id INTEGER PRIMARY KEY
);

-- 2. Tables that depend on COUNTRY, TOURNAMENT or HOTEL.
-- Each participant is sent by exactly one country.
CREATE TABLE participant (
    member_number INTEGER PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    address VARCHAR(250) NOT NULL,
    phone_number VARCHAR(30) NOT NULL,
    country_number INTEGER NOT NULL,

    CONSTRAINT fk_participant_country
        FOREIGN KEY (country_number)
        REFERENCES country (country_number)
        ON DELETE RESTRICT
);

-- A date identifies a day only within its tournament.
-- Pending rule: each tournament must have at least one day.
CREATE TABLE tournament_day (
    tournament_id INTEGER NOT NULL,
    play_date DATE NOT NULL,

    CONSTRAINT pk_tournament_day
        PRIMARY KEY (tournament_id, play_date),

    CONSTRAINT fk_tournament_day_tournament
        FOREIGN KEY (tournament_id)
        REFERENCES tournament (tournament_id)
        ON DELETE RESTRICT
);
-- A room number is unique only within its hotel.
CREATE TABLE playing_room (
    hotel_id INTEGER NOT NULL,
    room_number INTEGER NOT NULL,
    capacity INTEGER NOT NULL,

    CONSTRAINT pk_playing_room
        PRIMARY KEY (hotel_id, room_number),

    CONSTRAINT ck_playing_room_number
        CHECK (room_number > 0),

    CONSTRAINT ck_playing_room_capacity
        CHECK (capacity >= 0),

    CONSTRAINT fk_playing_room_hotel
        FOREIGN KEY (hotel_id)
        REFERENCES hotel (hotel_id)
        ON DELETE RESTRICT
);

-- 3. Participant subtypes reuse PARTICIPANT's primary key as a foreign key.
-- Pending rule: each participant must be exactly one of PLAYER or ARBITER.
-- Pending rules: each player must play, and each arbiter must officiate at least one game.
CREATE TABLE player (
    member_number INTEGER PRIMARY KEY,
    skill_level SMALLINT NOT NULL,

    CONSTRAINT ck_player_skill_level
        CHECK (skill_level BETWEEN 1 AND 10),

    CONSTRAINT fk_player_participant
        FOREIGN KEY (member_number)
        REFERENCES participant (member_number)
        ON DELETE RESTRICT
);
CREATE TABLE arbiter (
    member_number INTEGER PRIMARY KEY,

    CONSTRAINT fk_arbiter_participant
        FOREIGN KEY (member_number)
        REFERENCES participant (member_number)
        ON DELETE RESTRICT
);

-- 4. Tournament registrations and optional hotel stays depend on PARTICIPANT.
-- Junction table for the many-to-many relationship between participants and tournaments.
-- Pending rule: each participant must be registered in at least one tournament.
CREATE TABLE tournament_participant (
    member_number INTEGER NOT NULL,
    tournament_id INTEGER NOT NULL,

    CONSTRAINT pk_tournament_participant
        PRIMARY KEY (member_number, tournament_id),

    CONSTRAINT fk_tournament_participant_participant
        FOREIGN KEY (member_number)
        REFERENCES participant (member_number)
        ON DELETE RESTRICT,

    CONSTRAINT fk_tournament_participant_tournament
        FOREIGN KEY (tournament_id)
        REFERENCES tournament (tournament_id)
        ON DELETE RESTRICT
);
-- Each row records one visit; participants may have no stays or return to the same hotel.
CREATE TABLE hotel_stay (
    stay_id INTEGER PRIMARY KEY,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    member_number INTEGER NOT NULL,
    hotel_id INTEGER NOT NULL,

    CONSTRAINT fk_hotel_stay_participant
        FOREIGN KEY (member_number)
        REFERENCES participant (member_number)
        ON DELETE RESTRICT,

    CONSTRAINT fk_hotel_stay_hotel
        FOREIGN KEY (hotel_id)
        REFERENCES hotel (hotel_id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_hotel_stay_dates
        CHECK (start_date <= end_date)
);

-- 5. A room's multiple broadcast resources are stored as separate rows.
-- The composite PK prevents repeating a resource within the same hotel room.
CREATE TABLE room_broadcast_resource (
    hotel_id INTEGER NOT NULL,
    room_number INTEGER NOT NULL,
    broadcast_resource VARCHAR(100) NOT NULL,

    CONSTRAINT pk_room_broadcast_resource
        PRIMARY KEY (hotel_id, room_number, broadcast_resource),

    CONSTRAINT fk_room_broadcast_resource_playing_room
        FOREIGN KEY (hotel_id, room_number)
        REFERENCES playing_room (hotel_id, room_number)
        ON DELETE RESTRICT
);

-- 6. GAME depends on ARBITER, TOURNAMENT_DAY, PLAYING_ROOM and TOURNAMENT_PARTICIPANT.
-- Game numbers are unique across all tournaments.
-- Pending rule: assign game numbers consecutively.
CREATE TABLE game (
    game_number INTEGER PRIMARY KEY,
    -- Tickets sold belong to this game in its assigned room.
    tickets_sold INTEGER NOT NULL,
    arbiter_member_number INTEGER NOT NULL,
    tournament_id INTEGER NOT NULL,
    play_date DATE NOT NULL,
    hotel_id INTEGER NOT NULL,
    room_number INTEGER NOT NULL,

    CONSTRAINT fk_game_arbiter
        FOREIGN KEY (arbiter_member_number)
        REFERENCES arbiter (member_number)
        ON DELETE RESTRICT,

    -- The tournament and date must match one row in TOURNAMENT_DAY.
    CONSTRAINT fk_game_tournament_day
        FOREIGN KEY (tournament_id, play_date)
        REFERENCES tournament_day (tournament_id, play_date)
        ON DELETE RESTRICT,

    -- The room number is checked together with its hotel.
    CONSTRAINT fk_game_playing_room
        FOREIGN KEY (hotel_id, room_number)
        REFERENCES playing_room (hotel_id, room_number)
        ON DELETE RESTRICT,

    -- This additional FK reuses existing columns to require
    -- the arbiter to be registered in the game's tournament.
    CONSTRAINT fk_game_registered_arbiter
        FOREIGN KEY (arbiter_member_number, tournament_id)
        REFERENCES tournament_participant (member_number, tournament_id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_game_tickets_sold
        CHECK (tickets_sold >= 0)
);

-- 7. GAME_PLAYER depends on GAME and PLAYER; MOVE depends on GAME.
-- Junction table linking games and players; the color belongs to this relationship.
-- Pending rules: exactly two players per game, both registered in its tournament.
CREATE TABLE game_player (
    game_number INTEGER NOT NULL,
    member_number INTEGER NOT NULL,
    piece_color VARCHAR(7) NOT NULL,

    CONSTRAINT pk_game_player
        PRIMARY KEY (game_number, member_number),

    -- With NOT NULL and the color CHECK, this allows at most two players.
    CONSTRAINT uq_game_player_color
        UNIQUE (game_number, piece_color),

    CONSTRAINT fk_game_player_game
        FOREIGN KEY (game_number)
        REFERENCES game (game_number)
        ON DELETE RESTRICT,

    CONSTRAINT fk_game_player_player
        FOREIGN KEY (member_number)
        REFERENCES player (member_number)
        ON DELETE RESTRICT,

    CONSTRAINT ck_game_player_color
        CHECK (piece_color IN ('white', 'black'))
);

-- A move number identifies a move only within its game.
-- Pending rule: each game must have at least one move.
CREATE TABLE move (
    game_number INTEGER NOT NULL,
    move_number INTEGER NOT NULL,
    move_notation VARCHAR(50) NOT NULL,
    expert_comment TEXT NOT NULL,

    CONSTRAINT pk_move
        PRIMARY KEY (game_number, move_number),

    CONSTRAINT fk_move_game
        FOREIGN KEY (game_number)
        REFERENCES game (game_number)
        ON DELETE RESTRICT,

    CONSTRAINT ck_move_number
        CHECK (move_number > 0)
);

COMMIT;
