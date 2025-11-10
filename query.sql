-- 1. Phim còn đang chiếu
-- Mục đích: Lấy các phim chưa kết thúc thời gian chiếu (CloseDate >= hôm nay)
-- Bảng sử dụng: Movie (đơn bảng)
-- CloseDate >= CAST(GETDATE() AS DATE): so sánh ngày, bỏ phần giờ để tránh lệch thời điểm trong ngày
-- Có thể mở rộng: thêm điều kiện ReleaseDate <= GETDATE() để tránh phim tương lai
SELECT MovieId, MovieName, Duration, ReleaseDate, CloseDate
FROM Movie
WHERE CloseDate >= CAST(GETDATE() AS DATE);
GO

-- 2. Phim thỏa nhiều điều kiện
-- Mục đích: Lọc phim có độ dài từ 90-150 phút, phát hành trong 6 tháng gần đây và đảm bảo CloseDate > ReleaseDate
-- Duration BETWEEN 90 AND 150: lọc khoảng thời lượng hợp lý
-- ReleaseDate >= DATEADD(MONTH,-6, ...): chỉ lấy phim mới (6 tháng qua)
-- CloseDate > ReleaseDate: đảm bảo ngày kết thúc sau ngày phát hành (loại dữ liệu lỗi)
SELECT MovieId, MovieName, Duration, ReleaseDate, CloseDate
FROM Movie
WHERE Duration BETWEEN 90 AND 150
  AND ReleaseDate >= DATEADD(MONTH,-6,CAST(GETDATE() AS DATE))
  AND CloseDate > ReleaseDate;
GO

-- 3. Top 10 phim mới nhất
-- Mục đích: Lấy 10 phim phát hành gần nhất, nếu trùng ngày ưu tiên phim có Duration dài hơn
-- ORDER BY ReleaseDate DESC, Duration DESC: sắp mới nhất trước, sau đó phim dài hơn
-- TOP 10: giới hạn kết quả
SELECT TOP 10 MovieId, MovieName, ReleaseDate, Duration
FROM Movie
ORDER BY ReleaseDate DESC, Duration DESC;
GO

-- 4. Liệt kê phim và thể loại
-- Mục đích: Ghép tên phim với tên thể loại tương ứng
-- JOIN Genre g ON m.GenreID = g.GenreID: bắt buộc phim phải có thể loại (INNER JOIN)
-- Nếu muốn hiển thị phim chưa có thể loại: đổi JOIN -> LEFT JOIN
SELECT m.MovieId, m.MovieName, g.GenreName
FROM Movie m
JOIN Genre g ON m.GenreID = g.GenreID;
GO

-- 5. Số vé bán theo suất
-- Mục đích: Đếm tổng số vé đã bán cho từng suất chiếu
-- LEFT JOIN Ticket: đảm bảo suất chưa bán vé vẫn xuất hiện với COUNT = 0
-- GROUP BY ShowID, ShowDate, ShowTime: gom theo suất (đủ các cột không tổng hợp)
-- ORDER BY ShowDate DESC, ShowTime DESC: suất mới nhất trước
SELECT s.ShowID, s.ShowDate, s.ShowTime, COUNT(t.TicketID) AS TicketsSold
FROM Show s
LEFT JOIN Ticket t ON s.ShowID = t.ShowID
GROUP BY s.ShowID, s.ShowDate, s.ShowTime
ORDER BY s.ShowDate DESC, s.ShowTime DESC;
GO

-- 6. Hợp danh sách tên
-- Mục đích: Tạo một danh sách chung bao gồm tên thể loại phim và loại ghế
-- UNION: loại bỏ trùng lặp (set semantics). Dùng UNION ALL nếu muốn giữ trùng để phân tích tần suất
-- Cột Source: giúp phân biệt nguồn dữ liệu
SELECT GenreName AS Name, N'Genre' AS Source
FROM Genre
UNION
SELECT TypeName AS Name, N'SeatType' AS Source
FROM SeatType;
GO

-- 7. Khách hàng có đánh giá
-- Mục đích: Tìm CustomerID xuất hiện ở cả bảng Customer (điều kiện Email IS NOT NULL) và Review
-- INTERSECT: trả về giao của hai tập hợp, loại trùng tự động
-- Tương đương (có thể thay) bằng INNER JOIN + DISTINCT
SELECT CustomerID
FROM Customer
WHERE Email IS NOT NULL
INTERSECT
SELECT CustomerID
FROM Review;
GO

-- 8. Khách hàng chưa từng đặt đơn
-- Mục đích: Danh sách khách hàng không có bất kỳ Order nào
-- EXCEPT: Tập ban đầu trừ đi các dòng xuất hiện ở truy vấn thứ hai
-- Có thể tối ưu bằng NOT EXISTS (hiệu quả hơn trên dữ liệu lớn)
SELECT CustomerID, Fullname
FROM Customer
EXCEPT
SELECT c.CustomerID, c.Fullname
FROM Customer c
JOIN [Order] o ON c.CustomerID = o.CustomerID;
GO

-- 9. Lịch sử đặt vé chi tiết khách hàng
-- Mục đích: Hiển thị từng vé của khách hàng cụ thể kèm phim, phòng, ghế, giá, trạng thái thanh toán
-- Chuỗi JOIN: Customer -> Order -> Ticket -> Show -> Movie -> Hall -> Payment
-- Biến @CustomerID: dễ tái sử dụng cho người dùng khác
-- Nếu muốn thấy cả Order chưa có vé: đổi JOIN Ticket thành LEFT JOIN Ticket
DECLARE @CustomerID INT = 1;
SELECT c.CustomerID, c.Fullname, o.OrderID, o.OrderTime,
       m.MovieName, s.ShowDate, s.ShowTime, h.Name AS HallName,
       t.Position AS SeatPosition, t.Price, p.Status AS PaymentStatus
FROM Customer c
JOIN [Order] o ON c.CustomerID = o.CustomerID
JOIN Ticket t ON o.OrderID = t.OrderID
JOIN Show s ON t.ShowID = s.ShowID
JOIN Movie m ON s.MovieId = m.MovieId
JOIN Hall h ON t.HallID = h.HallID
JOIN Payment p ON o.OrderID = p.OrderID
WHERE c.CustomerID = @CustomerID
ORDER BY o.OrderTime DESC;
GO

-- 10. Top 10 phim doanh thu + đánh giá
-- Mục đích: Kết hợp doanh thu bán vé và chất lượng (điểm trung bình, số review)
-- LEFT JOIN Show/Ticket/Review: vẫn thấy phim chưa chiếu hoặc chưa có đánh giá
-- COUNT(DISTINCT s.ShowID): số suất chiếu khác nhau
-- ISNULL(SUM(t.Price),0): doanh thu 0 nếu chưa bán vé
-- AVG(CAST(r.Rating AS FLOAT)): trung bình điểm (casting rõ ràng)
SELECT TOP 10 m.MovieId, m.MovieName, g.GenreName,
       COUNT(DISTINCT s.ShowID) AS TotalShows,
       COUNT(t.TicketID) AS TicketsSold,
       ISNULL(SUM(t.Price),0) AS Revenue,
       AVG(CAST(r.Rating AS FLOAT)) AS AvgRating,
       COUNT(r.CustomerID) AS ReviewCount
FROM Movie m
JOIN Genre g ON m.GenreID = g.GenreID
LEFT JOIN Show s ON m.MovieId = s.MovieId
LEFT JOIN Ticket t ON s.ShowID = t.ShowID
LEFT JOIN Review r ON m.MovieId = r.MovieId
GROUP BY m.MovieId, m.MovieName, g.GenreName
ORDER BY Revenue DESC, AvgRating DESC;
GO

-- 11. Doanh thu theo phương thức thanh toán
-- Mục đích: Tổng hợp giao dịch hoàn thành và doanh thu theo loại Payment
-- Xác định phương thức qua việc tồn tại dòng con (ví, tiền mặt, thẻ)
-- JOIN Order + Ticket để tính tổng tiền từ vé
-- GROUP BY biểu thức CASE trả về phương thức
SELECT CASE
           WHEN ew.PaymentID IS NOT NULL THEN N'Ví điện tử'
           WHEN cp.PaymentID IS NOT NULL THEN N'Tiền mặt'
           WHEN cc.PaymentID IS NOT NULL THEN N'Thẻ tín dụng'
           ELSE N'Khác' END AS PaymentMethod,
       COUNT(p.PaymentID) AS Transactions,
       SUM(t.Price) AS Revenue,
       AVG(t.Price) AS AvgValue
FROM Payment p
LEFT JOIN EWalletPayment ew ON p.PaymentID = ew.PaymentID
LEFT JOIN CashPayment cp ON p.PaymentID = cp.PaymentID
LEFT JOIN CreditCardPayment cc ON p.PaymentID = cc.PaymentID
JOIN [Order] o ON p.OrderID = o.OrderID
JOIN Ticket t ON o.OrderID = t.OrderID
WHERE p.Status = N'Hoàn thành'
GROUP BY CASE
             WHEN ew.PaymentID IS NOT NULL THEN N'Ví điện tử'
             WHEN cp.PaymentID IS NOT NULL THEN N'Tiền mặt'
             WHEN cc.PaymentID IS NOT NULL THEN N'Thẻ tín dụng'
             ELSE N'Khác' END
ORDER BY Revenue DESC;
GO

-- 12. Tỷ lệ lấp đầy phòng chiếu
-- Mục đích: Đo hiệu suất sử dụng phòng (OccupancyRate = vé bán / tổng sức chứa theo số suất)
-- SeatsPerShow = RowNumber * ColumnNumber (tổng ghế mỗi suất)
-- TotalCapacity = SeatsPerShow * TotalShows
-- NULLIF(...) để tránh chia cho 0 khi chưa có suất
SELECT h.HallID, h.Name AS HallName,
       COUNT(DISTINCT s.ShowID) AS TotalShows,
       (h.RowNumber * h.ColumnNumber) AS SeatsPerShow,
       COUNT(t.TicketID) AS TicketsSold,
       (h.RowNumber * h.ColumnNumber * COUNT(DISTINCT s.ShowID)) AS TotalCapacity,
       CAST( COUNT(t.TicketID) * 100.0 /
             NULLIF(CAST(h.RowNumber * h.ColumnNumber * COUNT(DISTINCT s.ShowID) AS DECIMAL(18,2)),0)
           AS DECIMAL(5,2)) AS OccupancyRate
FROM Hall h
LEFT JOIN Show s ON h.HallID = s.HallID
LEFT JOIN Ticket t ON s.ShowID = t.ShowID
GROUP BY h.HallID, h.Name, h.RowNumber, h.ColumnNumber
ORDER BY OccupancyRate DESC;
GO

-- 13. Top khách hàng chi tiêu
-- Mục đích: Xếp hạng khách hàng theo tổng giá vé đã thanh toán
-- Lọc Payment Status = 'Hoàn thành' để chỉ tính đơn thành công
-- COUNT(DISTINCT o.OrderID): số đơn; COUNT(t.TicketID): số vé; SUM(t.Price): tổng tiền
-- MAX(o.OrderTime): lần mua gần nhất
SELECT TOP 10 c.CustomerID, c.Fullname, c.Email, c.Phone,
       COUNT(DISTINCT o.OrderID) AS TotalOrders,
       COUNT(t.TicketID) AS TotalTickets,
       SUM(t.Price) AS TotalSpent,
       MAX(o.OrderTime) AS LastOrderTime
FROM Customer c
JOIN [Order] o ON c.CustomerID = o.CustomerID
JOIN Payment p ON o.OrderID = p.OrderID AND p.Status = N'Hoàn thành'
JOIN Ticket t ON o.OrderID = t.OrderID
GROUP BY c.CustomerID, c.Fullname, c.Email, c.Phone
ORDER BY TotalSpent DESC;
GO

-- 14. Doanh thu theo nhóm tuổi
-- Mục đích: Phân tích KPI (doanh thu, vé, số khách) theo nhóm tuổi động
-- DATEDIFF(YEAR, DOB, GETDATE()): tuổi xấp xỉ (không xét ngày sinh trong năm)
-- Có thể chính xác hơn bằng so sánh MONTH/DAY nếu cần
SELECT CASE
           WHEN DATEDIFF(YEAR, c.DOB, GETDATE()) < 18 THEN N'Dưới 18'
           WHEN DATEDIFF(YEAR, c.DOB, GETDATE()) BETWEEN 18 AND 25 THEN N'18-25'
           WHEN DATEDIFF(YEAR, c.DOB, GETDATE()) BETWEEN 26 AND 35 THEN N'26-35'
           WHEN DATEDIFF(YEAR, c.DOB, GETDATE()) BETWEEN 36 AND 50 THEN N'36-50'
           ELSE N'Trên 50' END AS AgeGroup,
       COUNT(DISTINCT c.CustomerID) AS Customers,
       COUNT(t.TicketID) AS Tickets,
       SUM(t.Price) AS Revenue,
       AVG(t.Price) AS AvgSpending
FROM Customer c
JOIN [Order] o ON c.CustomerID = o.CustomerID
JOIN Payment p ON o.OrderID = p.OrderID AND p.Status = N'Hoàn thành'
JOIN Ticket t ON o.OrderID = t.OrderID
WHERE c.DOB IS NOT NULL
GROUP BY CASE
             WHEN DATEDIFF(YEAR, c.DOB, GETDATE()) < 18 THEN N'Dưới 18'
             WHEN DATEDIFF(YEAR, c.DOB, GETDATE()) BETWEEN 18 AND 25 THEN N'18-25'
             WHEN DATEDIFF(YEAR, c.DOB, GETDATE()) BETWEEN 26 AND 35 THEN N'26-35'
             WHEN DATEDIFF(YEAR, c.DOB, GETDATE()) BETWEEN 36 AND 50 THEN N'36-50'
             ELSE N'Trên 50' END
ORDER BY Revenue DESC;
GO

-- 15. Trạng thái ghế một suất chiếu
-- Mục đích: Sơ đồ ghế realtime cho 1 suất chiếu cụ thể
-- Chuỗi JOIN để lấy đủ thông tin: Show -> Movie/Hall -> Seat -> SeatType + LEFT JOIN Ticket (kiểm tra đặt)
-- CASE WHEN t.TicketID IS NULL: xác định ghế trống/hết
-- ORDER BY seat.Position: dễ hiển thị theo thứ tự ghế
DECLARE @ShowID INT = 1;
SELECT seat.Position,
       st.TypeName,
       m.MovieName,
       s.ShowDate,
       s.ShowTime,
       h.Name AS HallName,
       CASE WHEN t.TicketID IS NULL THEN N'Còn trống' ELSE N'Đã đặt' END AS SeatStatus
FROM Show s
JOIN Movie m ON s.MovieId = m.MovieId
JOIN Hall h ON s.HallID = h.HallID
JOIN Seat seat ON h.HallID = seat.HallID
JOIN SeatType st ON seat.SeatTypeID = st.SeatTypeID
LEFT JOIN Ticket t ON t.ShowID = s.ShowID AND t.HallID = h.HallID AND t.Position = seat.Position
WHERE s.ShowID = @ShowID
ORDER BY seat.Position;
GO
