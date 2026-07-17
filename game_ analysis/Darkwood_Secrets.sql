/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Сухостовская Светлана
 * Дата: 07.12.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT COUNT(payer) AS total_players,
	SUM(payer) AS total_paying_users,
	AVG(payer)*100 AS proportion_payer_users  --поправила на более лаконичный вариант (с умножением на 100, чтобы видить %)
FROM fantasy.users;


-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT 
	race,
	SUM(payer) AS paying_races,
	COUNT(*) AS total_races_players,
	ROUND((SUM(payer)::numeric / COUNT(*)::NUMERIC)*100, 2) AS proportion_payer_races
FROM fantasy.users AS us
JOIN fantasy.race AS r USING(race_id)
GROUP BY race
ORDER BY proportion_payer_races DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT
    COUNT(transaction_id) AS total_transactions,
    SUM(amount) AS total_amount,
    MIN(amount) AS min_amount,
    MAX(amount) AS max_amount,
    ROUND(AVG(amount::numeric), 2) AS avg_amount,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median,
    ROUND(STDDEV(amount)::numeric, 2) AS stand_dev_amount
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
SELECT COUNT(*) AS anomaly_transactions,
	COUNT(*)::numeric / (SELECT COUNT(*) AS totaly_buy FROM fantasy.events)::NUMERIC * 100 AS percent_anomaly
FROM fantasy.events
WHERE amount = 0;

-- 2.3: Популярные эпические предметы:
WITH total_transactions AS (
	SELECT DISTINCT
		item_code,
		COUNT(transaction_id) OVER(PARTITION BY item_code) AS count_item_transactions,
		COUNT(transaction_id) OVER() AS total_buy
	FROM fantasy.events AS e
WHERE amount > 0
),
total_buers AS (
	SELECT 
		item_code,
		COUNT(DISTINCT id) AS total_item_buyer,
		ROUND((COUNT(DISTINCT id)::numeric / (SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount > 0)::NUMERIC) * 100, 2) AS percent_buyer
	FROM fantasy.events
	JOIN fantasy.items AS i USING(item_code)
	WHERE amount > 0
	GROUP BY item_code
)
SELECT 
	i.game_items,
	tt.item_code,
	count_item_transactions,
	ROUND((count_item_transactions::NUMERIC / total_buy::NUMERIC) * 100, 2) AS proportion_item_transactions,
	percent_buyer
FROM total_transactions AS tt
JOIN total_buers AS tb USING(item_code)
JOIN fantasy.items i USING(item_code)
ORDER BY percent_buyer DESC 
LIMIT 10;

-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH total_payers AS (
	SELECT 
		race_id,
		COUNT(*) AS total_players, -- всего игроков
		SUM(payer) AS paying_players, --совершают внутриигровые покупки (payer = 1), платящий
		ROUND((SUM(payer)::numeric / COUNT(*)::numeric)*100, 2) AS percent_pay_players -- % платящих от всех
	FROM fantasy.users
	GROUP BY race_id),
--доля платящих игроков среди игроков, которые совершили внутриигровые покупки в разрезе рас:
total_buyers AS(
	SELECT race_id,
		COUNT(DISTINCT id) AS total_players_buy, -- количество игроков, которые совершают внутриигровые покупки (лепескти)
		ROUND(AVG(amount)::numeric, 2) AS avg_amount,
		COUNT(e.transaction_id) / COUNT(DISTINCT id) AS avg_transactions
	FROM fantasy.events AS e
	LEFT JOIN fantasy.users AS u USING(id)
	LEFT JOIN total_payers AS r USING(race_id)
	WHERE amount > 0
	GROUP BY race_id
),
--Количество платящих игроков среди игроков, которые совершили внутриигровые покупки;
pay_players_buys AS (SELECT race_id,
		COUNT(DISTINCT id) AS pay_players_buy
	FROM fantasy.events e 
	JOIN fantasy.users u USING(id)
	WHERE e.amount > 0 AND payer = 1
	GROUP BY race_id
),
avg_bill AS (
	SELECT id,
		race_id, 
		SUM(e.amount) AS avg_one_user
		FROM fantasy.events AS e
	LEFT JOIN fantasy.users AS u USING(id)
	WHERE amount > 0
	GROUP BY id, race_id
),
avg_bill_race AS(
	SELECT DISTINCT 
		race_id,
		ROUND((AVG(avg_one_user) OVER(PARTITION BY race_id))::numeric, 2) AS avg_user_purchase
	FROM avg_bill
)
SELECT 
	race,
	total_players,
	total_players_buy,
	ROUND((total_players_buy::numeric / total_players::numeric) * 100, 2) AS percent_buyers, --% тех, кто совершал покупки от общего количества зарегистрированных игроков
	ROUND((pay_players_buy::numeric / total_players_buy::numeric) * 100, 2) AS percent_paying_buyers, -- доля платящих игроков среди игроков, которые совершили внутриигровые покупки
	avg_transactions, 
	avg_amount,
	avg_user_purchase,
	avg_user_purchase_v2 --расчет по 2 варианту
FROM total_payers AS r
LEFT JOIN total_buyers AS b USING(race_id)
LEFT JOIN avg_bill_race AS ab USING(race_id)
LEFT JOIN pay_players_buys AS ppb USING(race_id)
LEFT JOIN fantasy.race AS rc USING(race_id);
