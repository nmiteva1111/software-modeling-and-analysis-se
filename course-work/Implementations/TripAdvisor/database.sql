/// Initialization ///
CREATE DATABASE TripAdvisor_Final
GO

USE TripAdvisor_Final
GO

/*
   TABLES
   */

CREATE TABLE UserAccount (
    user_id INT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL,
    country VARCHAR(50),
    join_date DATE NOT NULL,
    display_name VARCHAR(100) NULL,
    password_hash VARCHAR(255) NULL,
    is_verified BIT NOT NULL DEFAULT 0
);
GO

CREATE TABLE Destination (
    destination_id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    country VARCHAR(50) NOT NULL,
    region VARCHAR(50) NOT NULL,
    description VARCHAR(255) NULL
);
GO

CREATE TABLE Place (
    place_id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,  -- hotel / restaurant / attraction
    destination_id INT NOT NULL,
    price_level INT,
    address VARCHAR(150) NULL,
    phone VARCHAR(30) NULL,
    website VARCHAR(200) NULL,
    average_rating NUMERIC(4,2) NULL,

    CONSTRAINT FK_Place_Destination
        FOREIGN KEY (destination_id) REFERENCES Destination(destination_id)
);
GO

CREATE TABLE Review (
    review_id INT PRIMARY KEY,
    user_id INT NOT NULL,
    place_id INT NOT NULL,
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title VARCHAR(120) NULL,
    review_text VARCHAR(255),
    review_date DATE NOT NULL,

    CONSTRAINT FK_Review_User
        FOREIGN KEY (user_id) REFERENCES UserAccount(user_id),
    CONSTRAINT FK_Review_Place
        FOREIGN KEY (place_id) REFERENCES Place(place_id)
);
GO

CREATE TABLE Photo (
    photo_id INT PRIMARY KEY,
    user_id INT NOT NULL,
    place_id INT NOT NULL,
    uploaded_at DATE NOT NULL,
    url VARCHAR(255) NULL,
    caption VARCHAR(255) NULL,

    CONSTRAINT FK_Photo_User
        FOREIGN KEY (user_id) REFERENCES UserAccount(user_id),
    CONSTRAINT FK_Photo_Place
        FOREIGN KEY (place_id) REFERENCES Place(place_id)
);
GO

CREATE TABLE Trip (
    trip_id INT PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,

    CONSTRAINT FK_Trip_User
        FOREIGN KEY (user_id) REFERENCES UserAccount(user_id),

    CONSTRAINT CK_Trip_Dates CHECK (end_date >= start_date)
);
GO

CREATE TABLE TripPlace (
    trip_id INT NOT NULL,
    place_id INT NOT NULL,
    day_number INT,
    notes VARCHAR(255) NULL,

    PRIMARY KEY (trip_id, place_id),
    CONSTRAINT FK_TripPlace_Trip
        FOREIGN KEY (trip_id) REFERENCES Trip(trip_id),
    CONSTRAINT FK_TripPlace_Place
        FOREIGN KEY (place_id) REFERENCES Place(place_id)
);
GO


/* 
   FUNCTION – средна оценка по дестинация
    */
CREATE FUNCTION fn_AvgRatingByDestination (@DestinationId INT)
RETURNS NUMERIC(4,2)
AS
BEGIN
    DECLARE @avg NUMERIC(4,2);

    SELECT @avg = CAST(AVG(CAST(r.rating AS NUMERIC(10,2))) AS NUMERIC(4,2))
    FROM Review r
    JOIN Place p ON r.place_id = p.place_id
    WHERE p.destination_id = @DestinationId;

    RETURN @avg;
END;
GO


/* 
   STORED PROCEDURE – статистика за местата
   */
CREATE PROCEDURE usp_PlaceStats
AS
BEGIN
    SELECT 
        p.place_id,
        p.name AS PlaceName,
        p.category AS Category,
        d.name AS Destination,
        COUNT(r.review_id) AS ReviewCount,
        CAST(AVG(CAST(r.rating AS NUMERIC(10,2))) AS NUMERIC(4,2)) AS AvgRating
    FROM Place p
    JOIN Destination d ON p.destination_id = d.destination_id
    LEFT JOIN Review r ON p.place_id = r.place_id
    GROUP BY p.place_id, p.name, p.category, d.name;
END;
GO


/* 
   TRIGGER + HISTORY TABLE – история на ревютата
   */
CREATE TABLE ReviewHistory (
    change_id INT IDENTITY(1,1) PRIMARY KEY,
    review_id INT NOT NULL,
    user_id INT NOT NULL,
    place_id INT NOT NULL,
    rating INT NOT NULL,
    title VARCHAR(120) NULL,
    review_text VARCHAR(255),
    review_date DATE NOT NULL,
    changed_on DATETIME NOT NULL,
    operation CHAR(3) NOT NULL CHECK (operation IN ('INS','DEL'))
);
GO

CREATE TRIGGER trg_ReviewHistory
ON Review
AFTER INSERT, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO ReviewHistory
    (review_id, user_id, place_id, rating, title, review_text, review_date, changed_on, operation)
    SELECT
        i.review_id,
        i.user_id,
        i.place_id,
        i.rating,
        i.title,
        i.review_text,
        i.review_date,
        GETDATE(),
        'INS'
    FROM INSERTED i

    UNION ALL

    SELECT
        d.review_id,
        d.user_id,
        d.place_id,
        d.rating,
        d.title,
        d.review_text,
        d.review_date,
        GETDATE(),
        'DEL'
    FROM DELETED d;
END;
GO


/* 
   TRIGGER – автоматично обновяване на Place.average_rating
   */
CREATE TRIGGER trg_RecalcPlaceAvgRating
ON Review
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH ChangedPlaces AS (
        SELECT place_id FROM inserted
        UNION
        SELECT place_id FROM deleted
    )
    UPDATE p
    SET average_rating = (
        SELECT CAST(AVG(CAST(r.rating AS NUMERIC(10,2))) AS NUMERIC(4,2))
        FROM Review r
        WHERE r.place_id = p.place_id
    )
    FROM Place p
    JOIN ChangedPlaces cp ON cp.place_id = p.place_id;
END;
GO


/* SAMPLE DATA
 */

INSERT INTO UserAccount (user_id, username, email, country, join_date, display_name, password_hash, is_verified) VALUES
(1, 'maria',  'maria@mail.com',  'Bulgaria', '2023-01-10', 'Maria Petrova',  'hash_maria',  1),
(2, 'ivan',   'ivan@mail.com',   'Italy',    '2023-02-15', 'Ivan Rossi',     'hash_ivan',   0),
(3, 'anna',   'anna@mail.com',   'Germany',  '2023-03-01', 'Anna Keller',    'hash_anna',   1),
(4, 'george', 'george@mail.com', 'Spain',    '2023-04-10', 'George Sanchez', 'hash_george', 0),
(5, 'elena',  'elena@mail.com',  'Greece',   '2023-05-12', 'Elena Dimitrou', 'hash_elena',  1);
GO

INSERT INTO Destination (destination_id, name, country, region, description) VALUES
(1, 'Paris',      'France',   'Europe', 'Capital city, museums and landmarks'),
(2, 'Rome',       'Italy',    'Europe', 'Historic city with ancient sites'),
(3, 'Sofia',      'Bulgaria', 'Europe', 'Capital city, culture and food'),
(4, 'Barcelona',  'Spain',    'Europe', 'Sea, architecture and nightlife');
GO

INSERT INTO Place (place_id, name, category, destination_id, price_level, address, phone, website, average_rating) VALUES
(1, 'Paris City Hotel',       'hotel',      1, 4, '10 Rue Example, Paris',       '+33 111 222',  'https://pariscityhotel.example', NULL),
(2, 'Colosseum',              'attraction', 2, 5, 'Piazza del Colosseo, Rome',   '+39 333 444',  'https://colosseum.example',      NULL),
(3, 'Happy Sofia Restaurant', 'restaurant', 3, 3, '1 Vitosha Blvd, Sofia',       '+359 888 111', 'https://happysofia.example',     NULL),
(4, 'Sofia Center Hotel',     'hotel',      3, 4, '5 Center St, Sofia',          '+359 888 222', 'https://sofiacenterhotel.example',NULL),
(5, 'Rome Pizza House',       'restaurant', 2, 3, '12 Pizza St, Rome',           '+39 555 666',  'https://romepizza.example',      NULL),
(6, 'Paris City Museum',      'attraction', 1, 5, '20 Museum Rd, Paris',         '+33 777 888',  'https://parismuseum.example',    NULL),
(7, 'Barcelona Beach',        'attraction', 4, 5, 'Barceloneta, Barcelona',      '+34 999 000',  'https://barcelonabeach.example', NULL),
(8, 'Barcelona Center Hotel', 'hotel',      4, 4, '2 Center Ave, Barcelona',     '+34 111 333',  'https://barcelonahotel.example', NULL),
(9, 'Tapas Barcelona',        'restaurant', 4, 3, '7 Tapas St, Barcelona',       '+34 444 555',  'https://tapasbarcelona.example', NULL);
GO

INSERT INTO Review (review_id, user_id, place_id, rating, title, review_text, review_date) VALUES
(1,  1, 1, 5, 'Excellent stay', 'Great hotel in the center',   '2024-01-05'),
(2,  2, 2, 4, 'Must visit',     'Very interesting place',      '2024-01-06'),
(3,  1, 3, 3, 'Okay',          'Good food but slow service',   '2024-01-07'),
(4,  2, 1, 4, 'Nice',          'Clean and comfortable hotel',  '2024-02-01'),
(5,  3, 1, 5, 'Amazing',       'Amazing experience',           '2024-02-03'),
(6,  4, 2, 3, 'Crowded',       'Too many people',              '2024-02-05'),
(7,  5, 3, 4, 'Tasty',         'Very tasty food',              '2024-02-06'),
(8,  1, 4, 5, 'Modern',        'New and modern hotel',         '2024-02-10'),
(9,  3, 5, 4, 'Authentic',     'Real Italian pizza',           '2024-02-11'),
(10, 4, 6, 5, 'Great museum',  'Incredible museum',            '2024-02-12'),
(11, 5, 7, 5, 'Perfect',       'Perfect beach for holiday',    '2024-03-01'),
(12, 3, 8, 4, 'Good',          'Good service',                 '2024-03-02'),
(13, 2, 9, 5, 'Best tapas',    'Best tapas ever!',             '2024-03-03');
GO

INSERT INTO Photo (photo_id, user_id, place_id, uploaded_at, url, caption) VALUES
(1,  1, 1, '2024-01-01', 'https://img.example/p1.jpg',  'Hotel lobby'),
(2,  1, 2, '2024-01-02', 'https://img.example/p2.jpg',  'Colosseum view'),
(3,  2, 3, '2024-01-03', 'https://img.example/p3.jpg',  'Dinner plate'),
(4,  2, 1, '2024-01-04', 'https://img.example/p4.jpg',  'Room photo'),
(5,  1, 2, '2024-01-05', 'https://img.example/p5.jpg',  'Ancient walls'),
(6,  2, 3, '2024-01-06', 'https://img.example/p6.jpg',  'Restaurant inside'),
(7,  3, 4, '2024-02-01', 'https://img.example/p7.jpg',  'Hotel exterior'),
(8,  4, 5, '2024-02-02', 'https://img.example/p8.jpg',  'Pizza closeup'),
(9,  5, 6, '2024-02-03', 'https://img.example/p9.jpg',  'Museum entrance'),
(10, 1, 5, '2024-02-04', 'https://img.example/p10.jpg', 'Pizza menu'),
(11, 2, 6, '2024-02-05', 'https://img.example/p11.jpg', 'Museum hall'),
(12, 5, 7, '2024-03-01', 'https://img.example/p12.jpg', 'Beach sunset'),
(13, 3, 8, '2024-03-02', 'https://img.example/p13.jpg', 'Hotel breakfast'),
(14, 2, 9, '2024-03-03', 'https://img.example/p14.jpg', 'Tapas table');
GO

INSERT INTO Trip (trip_id, user_id, name, start_date, end_date) VALUES
(1, 1, 'Trip to Paris',      '2024-01-01', '2024-01-07'),
(2, 2, 'Trip to Rome',       '2024-02-01', '2024-02-05'),
(3, 3, 'Trip to Sofia',      '2024-03-01', '2024-03-05'),
(4, 4, 'Trip around Europe', '2024-04-01', '2024-04-10'),
(5, 5, 'Trip to Barcelona',  '2024-05-01', '2024-05-05');
GO

INSERT INTO TripPlace (trip_id, place_id, day_number, notes) VALUES
(1, 1, 1, 'Check-in and rest'),
(1, 6, 2, 'Museum visit'),
(2, 2, 1, 'Morning tour'),
(2, 5, 2, 'Lunch stop'),
(3, 3, 1, 'Dinner reservation'),
(3, 4, 2, 'Hotel stay'),
(4, 1, 1, 'Start in Paris'),
(4, 2, 2, 'Move to Rome'),
(4, 5, 3, 'Try pizza'),
(5, 7, 1, 'Beach day'),
(5, 8, 2, 'Hotel check-in'),
(5, 9, 3, 'Tapas night');
GO

/* Initial calculation of average_rating (so it is not NULL) */
UPDATE p
SET average_rating = x.avg_rating
FROM Place p
JOIN (
    SELECT place_id, CAST(AVG(CAST(rating AS NUMERIC(10,2))) AS NUMERIC(4,2)) AS avg_rating
    FROM Review
    GROUP BY place_id
) x ON x.place_id = p.place_id;
GO
