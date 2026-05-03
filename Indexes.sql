-- Tăng tốc tìm theo EventID
CREATE INDEX idx_reg_event ON Registrations(EventID);

-- Tăng tốc tìm theo GuestID
CREATE INDEX idx_reg_guest ON Registrations(GuestID);

-- Tăng tốc lookup email (search khách)
CREATE INDEX idx_guest_email ON Guests(Email);

-- Kiểm tra
EXPLAIN SELECT * FROM Guests WHERE GuestID = '1';
EXPLAIN SELECT * FROM Guests WHERE Email = 'guest50@gmail.com';

-- 1. Upcoming Events (event sắp diễn ra)
CREATE VIEW Upcoming_Events AS
SELECT *
FROM Events
WHERE EventDate >= CURDATE();
-- SELECT * FROM Upcoming_Events;
-- 👉 Feature: lọc nhanh các event chưa diễn ra

------------------------------------------------

-- 2. Registered Guests (ai đăng ký event nào)
-- Nếu View đã tồn tại, ta dùng CREATE OR REPLACE để ghi đè lên
CREATE VIEW Registered_Guests AS
SELECT 
    e.EventDate,         -- Để biết sự kiện nào diễn ra trước
    e.EventName, 
    g.GuestName, 
    r.RegistrationDate   -- Để biết khách nào đăng ký trước
FROM Registrations r
JOIN Guests g ON r.GuestID = g.GuestID
JOIN Events e ON r.EventID = e.EventID
ORDER BY 
    e.EventDate ASC,      -- Ưu tiên 1: Sự kiện diễn ra sớm nhất lên đầu
    r.RegistrationDate ASC; -- Ưu tiên 2: Trong cùng 1 sự kiện, ai đăng ký trước hiện lên trước
 -- SELECT * FROM Registered_Guests;

-- 👉 Feature: hiển thị danh sách khách đã đăng ký

------------------------------------------------

-- 3. Event Summary (tổng số người mỗi event)
CREATE VIEW Event_Summary AS
SELECT 
    e.EventName,
    COUNT(r.RegistrationID) AS Total_Registrations
FROM Events e
LEFT JOIN Registrations r ON e.EventID = r.EventID
GROUP BY e.EventID;

-- SELECT * FROM Event_Summary;


-- 👉 Feature: thống kê số lượng người tham gia mỗi event

DELIMITER $$

-- 1. Check-in guest (thêm đăng ký mới)
CREATE PROCEDURE CheckInGuest(IN p_guest INT, IN p_event INT)
BEGIN
    INSERT IGNORE INTO Registrations (EventID, GuestID, RegistrationDate)
    VALUES (p_event, p_guest, CURDATE());
END $$
-- VD: CALL CheckInGuest(50, 2);
-- SELECT * FROM Registrations WHERE GuestID = 50 AND EventID = 2;
-- - Tự động thêm đăng ký
-- - Tránh duplicate nhờ INSERT IGNORE

-- 2. Upcoming Event Reminder (event trong 7 ngày tới)
CREATE PROCEDURE EventReminder()
BEGIN
    SELECT EventName, EventDate
    FROM Events
    WHERE EventDate BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 7 DAY);
END $$

-- 👉 Feature:
-- - Lấy danh sách event sắp diễn ra
-- - Dùng để gửi reminder

DELIMITER ;

-- =========================================
-- FUNCTIONS: tính toán tái sử dụng
-- =========================================
DROP FUNCTION TotalGuests
-- 1. Total Guests per Event
DELIMITER $$

CREATE FUNCTION TotalGuests(event_id INT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE total INT;

    SELECT COUNT(*) INTO total
    FROM Registrations
    WHERE EventID = event_id;

    RETURN total;
END $$

DELIMITER ;
-- 👉 Feature: trả về tổng số khách của 1 event

------------------------------------------------

-- 2. Participation Rate (%)
DELIMITER $$

CREATE FUNCTION ParticipationRate(event_id INT)
RETURNS DECIMAL(5,2)
DETERMINISTIC
BEGIN
    DECLARE total INT;
    DECLARE total_guests INT;

    SELECT COUNT(*) INTO total
    FROM Registrations
    WHERE EventID = event_id;

    SELECT COUNT(*) INTO total_guests
    FROM Guests;

    RETURN ROUND((total * 100.0) / total_guests, 2);
END $$

DELIMITER ;
-- Test
SELECT 
    EventName,
    TotalGuests(EventID) AS SoKhach,
    ParticipationRate(EventID) AS Percent
FROM Events;
-- =========================================
-- VENUE USAGE
-- =========================================

SELECT 
    v.VenueName,
    COUNT(e.EventID) AS TotalEvents
FROM Venues v
LEFT JOIN Events e ON v.VenueID = e.VenueID
GROUP BY v.VenueID;

-- 👉 Feature:
-- - Xem venue nào được sử dụng nhiều

-- =========================================
-- ACCESS ROLES (FIXED VERSION)
-- =========================================

-- App user (cho Python)
CREATE USER IF NOT EXISTS 'app_user'@'localhost' IDENTIFIED BY 'fullfunction1';
GRANT ALL PRIVILEGES ON EventDB.* TO 'app_user'@'localhost';

-- Staff
CREATE USER IF NOT EXISTS 'staff'@'localhost' IDENTIFIED BY '123456';

GRANT SELECT ON EventDB.Events TO 'staff'@'localhost';
GRANT SELECT ON EventDB.Guests TO 'staff'@'localhost';
GRANT SELECT, INSERT ON EventDB.Registrations TO 'staff'@'localhost';


-- =========================================
-- DATA SECURITY: bảo vệ thông tin nhạy cảm
-- =========================================

-- Tạo view ẩn thông tin khách
CREATE VIEW Guest_Public AS
SELECT 
    GuestID,
    GuestName,

    -- Ẩn email (chỉ hiện 3 ký tự đầu)
    CONCAT(LEFT(Email, 3), '***@gmail.com') AS Email,

    -- Ẩn số điện thoại
    CONCAT('******', RIGHT(PhoneNumber, 2)) AS PhoneNumber

FROM Guests;

-- 👉 Feature:
-- - Mask dữ liệu nhạy cảm
-- - Dùng cho staff thay vì bảng thật

------------------------------------------------

-- Phân quyền: staff chỉ được xem view
REVOKE SELECT ON EventDB.Guests FROM 'staff'@'localhost';
GRANT SELECT ON EventDB.Guest_Public TO 'staff'@'localhost';

-- 👉 Feature:
-- - Staff không truy cập được dữ liệu gốc
-- - Tăng bảo mật

-- =========================================
-- DATA SECURITY: bảo vệ thông tin nhạy cảm
-- =========================================

-- Tạo view ẩn thông tin khách
CREATE VIEW Guest_Public AS
SELECT 
    GuestID,
    GuestName,

    -- Ẩn email (chỉ hiện 3 ký tự đầu)
    CONCAT(LEFT(Email, 3), '***@gmail.com') AS Email,

    -- Ẩn số điện thoại
    CONCAT('******', RIGHT(PhoneNumber, 2)) AS PhoneNumber

FROM Guests;

-- 👉 Feature:
-- - Mask dữ liệu nhạy cảm
-- - Dùng cho staff thay vì bảng thật

------------------------------------------------

-- Phân quyền: staff chỉ được xem view
REVOKE SELECT ON EventDB.Guests FROM 'staff'@'localhost';
GRANT SELECT ON EventDB.Guest_Public TO 'staff'@'localhost';

-- 👉 Feature:
-- - Staff không truy cập được dữ liệu gốc
-- - Tăng bảo mật

-- 2. Query tối ưu (dùng JOIN + GROUP BY)
SELECT 
    e.EventName,
    COUNT(r.RegistrationID) AS Total
FROM Events e
LEFT JOIN Registrations r ON e.EventID = r.EventID
GROUP BY e.EventID;

-- 👉 Feature:
-- - Truy vấn nhanh và hiệu quả

------------------------------------------------

-- 3. Bulk Insert (thêm nhiều dòng cùng lúc)
INSERT INTO Registrations (EventID, GuestID, RegistrationDate)
VALUES
(1,1,'2026-06-01'),
(1,2,'2026-06-01'),
(1,3,'2026-06-01');

-- 👉 Feature:
-- - Nhanh hơn insert từng dòng
