/*
Question #1: 
Calculate the proportion of sessions abandoned in summer months 
(June, July, August) and compare it to the proportion of sessions abandoned 
in non-summer months. Round the output to 3 decimal places.

Expected column names: summer_abandon_rate, other_abandon_rate
*/

-- q1 solution:

with CTE AS (SELECT	session_id, trip_id,
             				EXTRACT(MONTH FROM session_start) as start_month
							FROM sessions
            )


SELECT 		MAX(ROUND(((SELECT CAST (COUNT(*) AS float) 
         				FROM CTE 
         				WHERE start_month IN ( 6, 7, 8) AND trip_id IS NULL) /
							(SELECT CAST(COUNT(*) AS float) 
         				FROM CTE 
         			WHERE start_month IN ( 6, 7, 8))):: numeric, 3)) AS summer_abandon_rate,
			MAX(ROUND(((SELECT CAST (COUNT(*) AS float) 
          				FROM CTE 
          				WHERE start_month NOT IN (6, 7 , 8) AND trip_id IS NULL) / 
						(SELECT CAST(COUNT(*) AS float) 
          				FROM CTE 
          				WHERE start_month NOT IN (6, 7 , 8))):: numeric, 3)) AS other_abandon_rate
FROM CTE;


-- commenting on my observations about the output of my solution to q1

/*
Question #2: 
Bin customers according to their place in the session abandonment distribution as follows: 

1. number of abandonments greater than one standard deviation more than the mean. Call these customers “gt”.
2. number of abandonments fewer than one standard deviation less than the mean. Call these customers “lt”.
3. everyone else (the middle of the distribution). Call these customers “middle”.

calculate the number of customers in each group, the mean number of abandonments in each group, and the range of abandonments in each group.

Expected column names: distribution_loc, abandon_n, abandon_avg, abandon_range

*/

-- q2 solution:

WITH CTE2 AS (SELECT user_id, COUNT(session_id) AS abandon
            FROM sessions
            WHERE trip_id IS NULL
            GROUP BY user_id),

    CTE3 AS (SELECT (CASE WHEN abandon > (SELECT (AVG(abandon))  + (STDDEV(abandon)) FROM CTE2)  THEN 'gt'
            							WHEN abandon < (SELECT (AVG(abandon))  - (STDDEV(abandon)) FROM CTE2) THEN 'lt'
           	 							ELSE 'middle' END) AS distribution_loc, abandon, user_id
            FROM CTE2 GROUP BY abandon, user_id)


SELECT distribution_loc, COUNT(user_id) abandon_n, 
				ROUND(AVG(abandon), 3) abandon_avg,
				(MAX(abandon) - MIN(abandon)) abandon_range 

FROM CTE3 
GROUP BY distribution_loc;

/*
Question #3: 
Calculate the total number of abandoned sessions and the total number of sessions 
that resulted in a booking per day, but only for customers who reside in one of the 
top 5 cities (top 5 in terms of total number of users from city). 
Also calculate the ratio of booked to abandoned for each day. 
Return only the 5 most recent days in the dataset.

Expected column names: session_date, abandoned,booked, book_abandon_ratio

*/

-- q3 solution:

WITH aban AS (SELECT user_id, session_id as a_id, CAST(session_start AS DATE) session_date
            FROM sessions
            WHERE flight_booked = False),

    book AS (SELECT user_id, session_id, session_id as b_id, CAST(session_start AS DATE) session_date
            FROM sessions
            WHERE flight_booked = True)

SELECT a.session_date, COUNT(a.a_id) abandoned, COUNT(b.b_id) booked,
				ROUND(CAST((CAST(COUNT(b.b_id) AS float)/COUNT(a.a_id)) AS numeric), 3)  book_abandon_ratio
FROM aban a
LEFT JOIN book b
ON a.user_id = b.user_id
LEFT JOIN users u
ON a.user_id = u.user_id
GROUP BY u.home_city, a.session_date
ORDER BY COUNT(a.user_id) DESC
LIMIT 5;



/*
Question #4: 
Densely rank users from Saskatoon based on their ratio of successful bookings to abandoned bookings. 
then count how many users share each rank, with the most common ranks listed first.

note: if the ratio of bookings to abandons is null for a user, 
use the average bookings/abandons ratio of all Saskatoon users.

Expected column names: ba_rank, rank_count
*/

-- q4 solution:

WITH	aban AS (SELECT user_id, COUNT(session_id) as a_id
              FROM sessions
							WHERE flight_booked = False
							GROUP BY user_id),

			book AS (SELECT user_id,  COUNT(session_id) as b_id
               FROM sessions
               WHERE flight_booked = True
              	GROUP BY user_id),

			saskatoon_users AS(SELECT u.user_id user_id, ROUND(CAST(CAST(b.b_id AS float)/ab.a_id AS numeric), 3) ratio
                   			FROM users u
                   			LEFT JOIN book b
                  			ON u.user_id = b.user_id
                 			  LEFT JOIN aban ab
                   			ON u.user_id = ab.user_id
                   			WHERE U.home_city = 'saskatoon'
                   			ORDER BY b.user_id)


SELECT 
DENSE_RANK() OVER(ORDER BY COALESCE(ratio, (SELECT ROUND(AVG(ratio),3) FROM saskatoon_users)) DESC) AS ba_rank,
			COUNT(user_id) rank_count
		
FROM saskatoon_users
GROUP BY ratio
ORDER BY rank_count DESC;

