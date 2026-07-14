-- ====================================================================
-- Первичное знакомство с данными
-- Проверка данных в таблице purchases
-- ====================================================================

-- Первичный осмотр структуры таблицы и типов данных
SELECT *
FROM afisha.purchases
LIMIT 10;

-- Анализ уникальных типов устройств для последующей сегментации
SELECT DISTINCT device_type_canonical
FROM afisha.purchases;

-- Проверка используемых валют
SELECT DISTINCT currency_code
FROM afisha.purchases;
/*
В данных пресдатвлены заказы в RUB и KZT
 */

-- Точечный срез данных по конкретному событию 
SELECT *
FROM afisha.purchases p 
WHERE p.event_id = '37442'
LIMIT 10;

-- Подсчет общего объема выборки, проверка на дубликаты в ключевом поле order_id
SELECT count(p.order_id) AS total_count, 
	count (DISTINCT p.order_id) AS unique_order_count
FROM afisha.purchases p;
/*
Всего в данных 292 034 строк, дублей в поле order_id нет
 */

-- Анализ популярности мероприятий в разрезе возрастных ограничений
SELECT age_limit, COUNT(order_id) AS total_orders
FROM afisha.purchases p
GROUP BY age_limit
ORDER BY total_orders DESC;
/* 
Категории мероприятий с возрастными ограничениями 16+ и 12+ являются самими популярными
 */

-- Проверка всех колонок таблицы на наличие пропусков
SELECT 
    COUNT(*) AS total_rows,
    COUNT(order_id) AS filled_order_id,
    COUNT(user_id) AS filled_user_id,
    COUNT(created_dt_msk) AS filled_created_dt_msk,
    COUNT(created_ts_msk) AS filled_created_ts_msk,
    COUNT(event_id) AS filled_event_id,
    COUNT(cinema_circuit) AS filled_cinema_circuit,
    COUNT(age_limit) AS filled_age_limit,
    COUNT(currency_code) AS filled_currency_code,
    COUNT(device_type_canonical) AS filled_device_type_canonical,
    COUNT(revenue) AS filled_revenue,
    COUNT(service_name) AS filled_service_name,
    COUNT(tickets_count) AS filled_tickets_count,
    COUNT(total) AS filled_total
FROM afisha.purchases p;
/* 
Все проверенные поля вернули значение 292 034 строк, что равно общему числу записей (total_rows).
В исследуемой таблице afisha.purchases пропуски (NULL) полностью отсутствуют. 
Данные готовы к дальнейшему агрегированию и расчету метрик.
*/

-- Анализ популярности мероприятий в разрезе используемых пользователями устройств
SELECT device_type_canonical, 
	COUNT(p.order_id) AS total_orders
FROM afisha.purchases p 
GROUP BY device_type_canonical
ORDER BY total_orders DESC;

-- Проверка данных на целостность дат
SELECT MIN(created_dt_msk) AS first_date, 
	MAX(created_dt_msk) AS last_date
FROM afisha.purchases p;
/* 
Данные ограничены временным интервалом с 2024-06-01 по 2024-10-31
Выборка полностью соответствует условиям технического задания.
*/

-- ====================================================================
-- Проверка данных в таблице events
-- ====================================================================

-- Первичный осмотр структуры таблицы и типов данных
SELECT *
FROM afisha.events e 
LIMIT 10;

-- Подсчет общего объема строк таблицы, проверка на дубликаты в ключевом поле event_id
SELECT COUNT(*) AS total_count, 
	COUNT (DISTINCT event_id) AS key_count
FROM afisha.events e;

-- Анализ уникальных типов мероприятий
SELECT DISTINCT event_type_main
FROM afisha.events e;

-- Анализ уникальных типов мероприятий
SELECT event_type_main, count(order_id) AS event_type_count
FROM afisha.purchases p
LEFT JOIN afisha.events e USING(event_id)
GROUP BY event_type_main
ORDER BY event_type_count DESC;

-- ====================================================================
-- Первичный финансовый анализ и поиск аномалий
-- ====================================================================

-- Расчет базовых статистических метрик выручки в разрезе используемых валют
SELECT currency_code, 
    AVG(revenue) AS avg_revenue, 
    MIN(revenue) AS min_revenue, 
    MAX(revenue) AS max_revenue, 
    STDDEV(revenue) AS std_dev_revenue, 
    SUM(revenue) AS total_revenue
FROM afisha.purchases p
GROUP BY currency_code;

/* 
1. Значения выручки имеют разный масштаб (средний чек в KZT — ~4995, в RUB — ~547). Прямое суммирование общего поля total_revenue 
   без предварительной конвертации по курсу валют недопустимо и приведет к искажению бизнес-метрик.

2. Обнаружена аномалия в российских рублях: MIN(revenue) составляет -90.76. 
   Отрицательная выручка указывает на наличие возвратов билетов или транзакционных сбоев. 
   При расчете чистой прибыли данные строки необходимо отфильтровать (WHERE revenue >= 0).

3. Высокое стандартное отклонение в обеих валютах подтверждает сильную неоднородность 
   стоимости заказов (наличие как дешевых билетов в кино, так и дорогих мероприятий).
*/

-- Поиск пропусков в поле revenue
SELECT revenue
FROM afisha.purchases p
WHERE revenue IS NULL;

-- Проверка справочника городов на наличие пустых значений
SELECT *
FROM afisha.city c 
WHERE city_name IS NULL;

/* 
Оба запроса вернули пустой результат. Пропуски в поле выручки и в справочнике городов отсутствуют. 
Справочные данные целостны, что гарантирует корректность последующего объединения таблиц (JOIN) 
и исключает потерю транзакций при анализе продаж по регионам.
*/

-- Подсчет общего количества регионов присутствия сервиса
SELECT COUNT(*)
FROM afisha.regions r 

-- Первичный осмотр справочника площадок проведения мероприятий (venues)
SELECT *
FROM afisha.venues v 
LIMIT 10;

-- Анализ активности билетных партнеров по количеству обработанных заказов
SELECT service_name, count(order_id) AS service_name_count
FROM afisha.purchases p
GROUP BY service_name
ORDER BY service_name_count DESC;

--  Расчет бизнес-метрик и юнит-экономики
SELECT currency_code,
	SUM(revenue) AS total_revenue,
	AVG(revenue) AS avg_revenue_per_order,
	COUNT(order_id) AS total_orders,
	COUNT(DISTINCT user_id) AS total_users,
	COUNT(order_id) / COUNT(DISTINCT user_id) AS avg_user_orders
FROM afisha.purchases
GROUP BY currency_code
ORDER BY SUM(revenue) DESC;
/* 
1. Масштаб рынков: Российский сегмент (RUB) является основным драйвером выручки (157.1 млн) 
   и генерирует 286,961 заказ. Казахстанский сегмент (KZT) приносит 25.3 млн при 5,073 заказах.
2. Концентрация клиентов: В рублевой зоне один уникальный пользователь совершает в среднем 
   ~13.4 заказа (286961 / 21422), в то время как в зоне KZT — всего ~3.7 заказа (5073 / 1362). 
   Это указывает на зрелость и высокую лояльность аудитории в РФ и большой потенциал роста частоты покупок в Казахстане.
*/

-- Анализ распределения финансового результата по типам устройств пользователей в рублевой выручке сервиса.
SELECT device_type_canonical,
    SUM(revenue) AS total_revenue,
    COUNT(order_id) AS total_orders,
    AVG(revenue) AS avg_revenue_per_order,
    ROUND(SUM(revenue)::numeric / SUM(SUM(revenue)) OVER()::numeric, 3) AS revenue_share
FROM afisha.purchases
WHERE currency_code = 'rub'
GROUP BY device_type_canonical
ORDER BY revenue_share DESC;
/* 
Основная часть выручки приходится на мобильные устройства и стационарные компьютеры. 
Доля остальных устройств в структуре выручки минимальна и составляет меньше процента.
*/

-- Изучение распределения выручки в разрезе типа мероприятий для заказов в рублях 
SELECT 
    event_type_main,
    SUM(revenue) AS total_revenue,
    COUNT(order_id) AS total_orders,
    AVG(revenue) AS avg_revenue_per_order,
    COUNT(DISTINCT event_name_code) AS total_event_name,
    AVG(tickets_count) AS avg_tickets
FROM afisha.purchases p 
LEFT JOIN afisha.events e USING(event_id)
WHERE currency_code = 'rub'
GROUP BY event_type_main
ORDER BY total_orders DESC;
/*
Среди наиболее популярных событий — концерты, театральные постановки и "другое".
*/

-- Объединение таблиц покупок и мероприятий для детального анализа 
-- категорий событий по выручке, заказам, среднему чеку и стоимости одного билета.
SELECT 
    event_type_main,
    SUM(revenue) AS total_revenue,
    COUNT(order_id) AS total_orders,
    AVG(revenue) AS avg_revenue_per_order,
    COUNT(DISTINCT event_name_code) AS total_event_name,
    AVG(tickets_count) AS avg_tickets,
    SUM(revenue) / SUM(tickets_count) AS avg_ticket_revenue,
    ROUND(SUM(revenue)::numeric / (SELECT SUM(revenue) 
                                    FROM afisha.purchases 
                                    WHERE currency_code = 'rub')::numeric, 3) 
                                    AS revenue_share
FROM afisha.purchases p 
LEFT JOIN afisha.events e USING(event_id)
WHERE currency_code = 'rub'
GROUP BY event_type_main
ORDER BY total_orders DESC;


-- Динамика изменения значений для заказов в рублях
-- Изменение выручки, количества заказов, уникальных клиентов и средней стоимости одного заказа в недельной динамике
SELECT DATE_TRUNC('week', created_dt_msk)::date AS week,
    SUM(revenue) AS total_revenue,
    COUNT(order_id) AS total_orders,
    COUNT(DISTINCT user_id) AS total_users,
    SUM(revenue) / COUNT(order_id) AS revenue_per_order
FROM afisha.purchases
WHERE currency_code = 'rub'
GROUP BY DATE_TRUNC('week', created_dt_msk)::date
ORDER BY week;
/*
виден рост количества заказов и пользователей к концу временного периода 
*/


-- Выделение топ-7 регионов по значению общей выручки для заказов в рублях
SELECT region_name,
    SUM(revenue) AS total_revenue,
    COUNT(order_id) AS total_orders,
    COUNT (DISTINCT user_id) AS total_users,
    SUM(tickets_count) AS total_tickets,
    SUM(revenue) / SUM(tickets_count) AS one_ticket_cost
FROM afisha.purchases p
LEFT JOIN afisha.events e USING(event_id)
LEFT JOIN afisha.city c USING(city_id)
LEFT JOIN afisha.regions r USING(region_id)
WHERE currency_code = 'rub'
GROUP BY region_name
ORDER BY total_revenue DESC 
LIMIT 7;
/*
Лидер: Каменевский регион генерирует основную долю рублевой выручки (более 61.5 млн руб.) и лидирует по числу заказов (91.6 тыс.)
Североярская область уверенно держит 2-е место по доходам (25.4 млн руб.)
 */

-- Когортный анализ: retention пользователей (по неделям)
WITH user_activity AS (
    SELECT 
        user_id,
        DATE_TRUNC('week', created_dt_msk)::date AS order_week,
        MIN(DATE_TRUNC('week', created_dt_msk)::date) OVER (PARTITION BY user_id) AS cohort_week,
        EXTRACT(WEEK FROM created_dt_msk) AS week_number
    FROM afisha.purchases
    WHERE currency_code = 'rub'
),
cohort_sizes AS (
    SELECT 
        cohort_week,
        COUNT(DISTINCT user_id) AS cohort_size
    FROM user_activity
    GROUP BY cohort_week
),
retention_raw AS (
    SELECT 
        ua.cohort_week,
        EXTRACT(WEEK FROM ua.order_week) - EXTRACT(WEEK FROM ua.cohort_week) AS week_offset,
        COUNT(DISTINCT ua.user_id) AS users_returned
    FROM user_activity ua
    GROUP BY ua.cohort_week, week_offset
)
SELECT 
    r.cohort_week,
    r.week_offset,
    r.users_returned,
    c.cohort_size,
    ROUND(100.0 * r.users_returned / c.cohort_size, 2) AS retention_rate
FROM retention_raw r
JOIN cohort_sizes c ON r.cohort_week = c.cohort_week
ORDER BY r.cohort_week, r.week_offset;
