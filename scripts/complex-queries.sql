-- 복잡한 쿼리 예제 for 쿼리 튜닝
-- 다양한 조인, 서브쿼리, 집계 함수, 윈도우 함수 포함

-- 1. 복잡한 조인 쿼리: 사용자별 구매 통계
-- 여러 테이블 조인, 집계 함수, 서브쿼리
SELECT 
    u.id,
    u.name,
    u.email,
    u.tier,
    COUNT(DISTINCT o.id) as total_orders,
    SUM(o.total_amount) as total_spent,
    AVG(o.total_amount) as avg_order_value,
    MAX(o.created_at) as last_order_date,
    COUNT(DISTINCT oi.product_id) as unique_products_purchased,
    SUM(CASE WHEN o.status = 'DELIVERED' THEN 1 ELSE 0 END) as delivered_orders,
    SUM(CASE WHEN o.status = 'CANCELLED' THEN 1 ELSE 0 END) as cancelled_orders
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
LEFT JOIN order_items oi ON o.id = oi.order_id
WHERE u.status = 'ACTIVE'
    AND u.registration_date >= '2023-01-01'
GROUP BY u.id, u.name, u.email, u.tier
HAVING COUNT(o.id) > 0
ORDER BY total_spent DESC
LIMIT 100;

-- 2. 서브쿼리와 CTE: 상품별 상세 분석
-- CTE, 여러 서브쿼리, 복잡한 조인
WITH product_stats AS (
    SELECT 
        p.id,
        p.name,
        p.category_id,
        p.brand_id,
        p.price,
        COUNT(DISTINCT oi.order_id) as order_count,
        SUM(oi.quantity) as total_sold,
        AVG(pr.rating) as avg_rating,
        COUNT(pr.id) as review_count,
        COUNT(DISTINCT pv.user_id) as view_count
    FROM products p
    LEFT JOIN order_items oi ON p.id = oi.product_id
    LEFT JOIN orders o ON oi.order_id = o.id AND o.status = 'DELIVERED'
    LEFT JOIN product_reviews pr ON p.id = pr.product_id AND pr.status = 'APPROVED'
    LEFT JOIN product_views pv ON p.id = pv.product_id
    WHERE p.status = 'ACTIVE'
    GROUP BY p.id, p.name, p.category_id, p.brand_id, p.price
),
category_performance AS (
    SELECT 
        c.id as category_id,
        c.name as category_name,
        COUNT(ps.id) as product_count,
        SUM(ps.order_count) as total_orders,
        SUM(ps.total_sold) as total_items_sold
    FROM categories c
    LEFT JOIN product_stats ps ON c.id = ps.category_id
    GROUP BY c.id, c.name
)
SELECT 
    ps.*,
    cp.category_name,
    cp.product_count as category_product_count,
    (ps.order_count * 100.0 / NULLIF(cp.total_orders, 0)) as category_order_share,
    (ps.total_sold * 100.0 / NULLIF(cp.total_items_sold, 0)) as category_volume_share,
    b.name as brand_name,
    CASE 
        WHEN ps.avg_rating >= 4.5 THEN 'EXCELLENT'
        WHEN ps.avg_rating >= 4.0 THEN 'GOOD'
        WHEN ps.avg_rating >= 3.5 THEN 'AVERAGE'
        ELSE 'POOR'
    END as rating_category
FROM product_stats ps
JOIN category_performance cp ON ps.category_id = cp.id
LEFT JOIN brands b ON ps.brand_id = b.id
WHERE ps.order_count > 10
ORDER BY ps.total_sold DESC, ps.avg_rating DESC
LIMIT 50;

-- 3. 윈도우 함수: 시계열 분석
-- 윈도우 함수, 날짜 함수, 복잡한 집계
SELECT 
    DATE_TRUNC('month', o.created_at) as month,
    c.name as category_name,
    COUNT(o.id) as order_count,
    SUM(o.total_amount) as total_revenue,
    AVG(o.total_amount) as avg_order_value,
    SUM(o.total_amount) OVER (
        PARTITION BY DATE_TRUNC('month', o.created_at)
        ORDER BY DATE_TRUNC('month', o.created_at)
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as cumulative_revenue,
    LAG(SUM(o.total_amount), 1) OVER (
        PARTITION BY c.id
        ORDER BY DATE_TRUNC('month', o.created_at)
    ) as previous_month_revenue,
    SUM(o.total_amount) - LAG(SUM(o.total_amount), 1) OVER (
        PARTITION BY c.id
        ORDER BY DATE_TRUNC('month', o.created_at)
    ) as revenue_change,
    CASE 
        WHEN LAG(SUM(o.total_amount), 1) OVER (
            PARTITION BY c.id
            ORDER BY DATE_TRUNC('month', o.created_at)
        ) > 0 
        THEN ((SUM(o.total_amount) - LAG(SUM(o.total_amount), 1) OVER (
            PARTITION BY c.id
            ORDER BY DATE_TRUNC('month', o.created_at)
        )) * 100.0 / LAG(SUM(o.total_amount), 1) OVER (
            PARTITION BY c.id
            ORDER BY DATE_TRUNC('month', o.created_at)
        ))
        ELSE NULL
    END as revenue_growth_rate
FROM orders o
JOIN order_items oi ON o.id = oi.order_id
JOIN products p ON oi.product_id = p.id
JOIN categories c ON p.category_id = c.id
WHERE o.status IN ('DELIVERED', 'PROCESSING')
    AND o.created_at >= '2023-01-01'
GROUP BY DATE_TRUNC('month', o.created_at), c.id, c.name
ORDER BY month DESC, total_revenue DESC;

-- 4. 복잡한 서브쿼리: 고객 세분화
-- 다중 서브쿼리, CASE 문, 복잡한 조건
SELECT 
    u.id,
    u.name,
    u.email,
    u.tier,
    u.registration_date,
    -- RFM 분석
    (SELECT DATEDIFF('day', MAX(o.created_at), CURRENT_DATE) 
     FROM orders o WHERE o.user_id = u.id) as recency_days,
    (SELECT COUNT(DISTINCT o.id) 
     FROM orders o WHERE o.user_id = u.id) as frequency,
    (SELECT SUM(o.total_amount) 
     FROM orders o WHERE o.user_id = u.id) as monetary,
    -- 고객 세그먼트
    CASE 
        WHEN (SELECT COUNT(DISTINCT o.id) FROM orders o WHERE o.user_id = u.id) >= 10 
             AND (SELECT SUM(o.total_amount) FROM orders o WHERE o.user_id = u.id) >= 1000000 
             AND (SELECT DATEDIFF('day', MAX(o.created_at), CURRENT_DATE) FROM orders o WHERE o.user_id = u.id) <= 30
        THEN 'VIP_CHAMPION'
        WHEN (SELECT COUNT(DISTINCT o.id) FROM orders o WHERE o.user_id = u.id) >= 5 
             AND (SELECT SUM(o.total_amount) FROM orders o WHERE o.user_id = u.id) >= 500000
        THEN 'LOYAL_CUSTOMER'
        WHEN (SELECT COUNT(DISTINCT o.id) FROM orders o WHERE o.user_id = u.id) >= 2 
             AND (SELECT DATEDIFF('day', MAX(o.created_at), CURRENT_DATE) FROM orders o WHERE o.user_id = u.id) <= 90
        THEN 'POTENTIAL_LOYALIST'
        WHEN (SELECT COUNT(DISTINCT o.id) FROM orders o WHERE o.user_id = u.id) = 1 
             AND (SELECT DATEDIFF('day', MAX(o.created_at), CURRENT_DATE) FROM orders o WHERE o.user_id = u.id) <= 30
        THEN 'NEW_CUSTOMER'
        WHEN (SELECT DATEDIFF('day', MAX(o.created_at), CURRENT_DATE) FROM orders o WHERE o.user_id = u.id) > 180
        THEN 'AT_RISK'
        WHEN (SELECT COUNT(DISTINCT o.id) FROM orders o WHERE o.user_id = u.id) = 0
        THEN 'NON_CUSTOMER'
        ELSE 'REGULAR_CUSTOMER'
    END as customer_segment,
    -- 선호 카테고리
    (SELECT c.name 
     FROM categories c 
     JOIN products p ON c.id = p.category_id 
     JOIN order_items oi ON p.id = oi.product_id 
     JOIN orders o ON oi.order_id = o.id 
     WHERE o.user_id = u.id 
     GROUP BY c.id, c.name 
     ORDER BY COUNT(oi.id) DESC 
     LIMIT 1) as favorite_category,
    -- 평균 주기
    (SELECT ROUND(AVG(DATEDIFF('day', 
        LAG(o.created_at) OVER (ORDER BY o.created_at), 
        o.created_at))) 
     FROM orders o 
     WHERE o.user_id = u.id 
     GROUP BY o.user_id) as avg_purchase_cycle_days
FROM users u
WHERE u.status = 'ACTIVE'
ORDER BY monetary DESC;

-- 5. 상관관계 분석: 제품 추천
-- 복잡한 조인, 서브쿼리, 상관관계 계산
WITH product_pairs AS (
    SELECT 
        o1.product_id as product_a,
        o2.product_id as product_b,
        COUNT(DISTINCT o1.order_id) as co_occurrence_count
    FROM order_items o1
    JOIN order_items o2 ON o1.order_id = o2.order_id AND o1.product_id < o2.product_id
    GROUP BY o1.product_id, o2.product_id
),
product_popularity AS (
    SELECT 
        p.id as product_id,
        p.name as product_name,
        COUNT(DISTINCT oi.order_id) as order_count
    FROM products p
    LEFT JOIN order_items oi ON p.id = oi.product_id
    WHERE p.status = 'ACTIVE'
    GROUP BY p.id, p.name
)
SELECT 
    pp.product_a,
    pa.product_name as product_a_name,
    pp.product_b,
    pb.product_name as product_b_name,
    pp.co_occurrence_count,
    pa.order_count as product_a_orders,
    pb.order_count as product_b_orders,
    -- 상관관계 점수 (Jaccard Index)
    (pp.co_occurrence_count * 1.0 / 
     NULLIF(pa.order_count + pb.order_count - pp.co_occurrence_count, 0)) as jaccard_similarity,
    -- 리프트 (구매 확률 증가)
    (pp.co_occurrence_count * 1.0 / NULLIF(pa.order_count, 0)) / 
    (pb.order_count * 1.0 / NULLIF((SELECT COUNT(DISTINCT order_id) FROM order_items), 0)) as lift_score
FROM product_pairs pp
JOIN product_popularity pa ON pp.product_a = pa.product_id
JOIN product_popularity pb ON pp.product_b = pb.product_id
WHERE pp.co_occurrence_count >= 10
ORDER BY jaccard_similarity DESC, lift_score DESC
LIMIT 100;

-- 6. 재고 분석 및 예측
-- 윈도우 함수, 집계, 복잡한 계산
WITH daily_sales AS (
    SELECT 
        p.id as product_id,
        p.name as product_name,
        DATE(o.created_at) as sale_date,
        SUM(oi.quantity) as daily_quantity_sold
    FROM products p
    JOIN order_items oi ON p.id = oi.product_id
    JOIN orders o ON oi.order_id = o.id
    WHERE o.status IN ('DELIVERED', 'PROCESSING')
        AND o.created_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY p.id, p.name, DATE(o.created_at)
),
sales_stats AS (
    SELECT 
        product_id,
        product_name,
        AVG(daily_quantity_sold) as avg_daily_sales,
        STDDEV(daily_quantity_sold) as sales_stddev,
        MAX(daily_quantity_sold) as max_daily_sales,
        MIN(daily_quantity_sold) as min_daily_sales
    FROM daily_sales
    GROUP BY product_id, product_name
)
SELECT 
    p.id,
    p.name,
    p.stock_quantity,
    ss.avg_daily_sales,
    ss.sales_stddev,
    ss.max_daily_sales,
    -- 재고 부족 예상일
    CASE 
        WHEN ss.avg_daily_sales > 0 
        THEN p.stock_quantity / ss.avg_daily_sales
        ELSE NULL
    END as days_of_stock_remaining,
    -- 재부팅 필요 여부
    CASE 
        WHEN ss.avg_daily_sales > 0 
             AND p.stock_quantity / ss.avg_daily_sales < 7 
        THEN 'URGENT'
        WHEN ss.avg_daily_sales > 0 
             AND p.stock_quantity / ss.avg_daily_sales < 14 
        THEN 'SOON'
        WHEN ss.avg_daily_sales > 0 
             AND p.stock_quantity / ss.avg_daily_sales < 30 
        THEN 'MONITOR'
        ELSE 'OK'
    END as restock_priority,
    -- 추천 재주문 수량
    CASE 
        WHEN ss.avg_daily_sales > 0 
        THEN GREATEST(
            ss.avg_daily_sales * 30,  -- 30일 평균
            ss.max_daily_sales * 7,   -- 최대 판매 7일분
            ss.avg_daily_sales * 1.5 + ss.sales_stddev * 2  -- 안전재고
        )
        ELSE NULL
    END as suggested_reorder_quantity
FROM products p
LEFT JOIN sales_stats ss ON p.id = ss.product_id
WHERE p.status = 'ACTIVE'
ORDER BY days_of_stock_remaining ASC NULLS LAST;

-- 7. A/B 테스트 분석
-- 복잡한 조건, 집계, 통계 계산
SELECT 
    CASE 
        WHEN u.id % 2 = 0 THEN 'CONTROL_GROUP'
        ELSE 'TEST_GROUP'
    END as experiment_group,
    COUNT(DISTINCT u.id) as user_count,
    COUNT(DISTINCT o.id) as conversion_count,
    (COUNT(DISTINCT o.id) * 100.0 / COUNT(DISTINCT u.id)) as conversion_rate,
    SUM(o.total_amount) as total_revenue,
    AVG(o.total_amount) as avg_revenue_per_user,
    AVG(CASE WHEN o.id IS NOT NULL THEN o.total_amount END) as avg_revenue_per_paying_user,
    -- 통계적 유의성을 위한 표준편차
    STDDEV(CASE WHEN o.id IS NOT NULL THEN o.total_amount END) as revenue_stddev
FROM users u
LEFT JOIN orders o ON u.id = o.user_id 
    AND o.created_at >= '2024-01-01'
    AND o.status = 'DELIVERED'
WHERE u.registration_date >= '2024-01-01'
    AND u.status = 'ACTIVE'
GROUP BY 
    CASE 
        WHEN u.id % 2 = 0 THEN 'CONTROL_GROUP'
        ELSE 'TEST_GROUP'
    END;

-- 8. 재방문율 및 유지율 분석
-- 복잡한 날짜 계산, 윈도우 함수
WITH user_cohorts AS (
    SELECT 
        u.id as user_id,
        DATE_TRUNC('month', u.registration_date) as cohort_month,
        u.registration_date as first_purchase_date
    FROM users u
    WHERE u.status = 'ACTIVE'
),
user_activities AS (
    SELECT 
        uc.user_id,
        uc.cohort_month,
        uc.first_purchase_date,
        DATE_TRUNC('month', o.created_at) as activity_month,
        DATEDIFF('month', uc.cohort_month, DATE_TRUNC('month', o.created_at)) as month_number
    FROM user_cohorts uc
    LEFT JOIN orders o ON uc.user_id = o.user_id
),
cohort_analysis AS (
    SELECT 
        cohort_month,
        month_number,
        COUNT(DISTINCT user_id) as active_users,
        FIRST_VALUE(COUNT(DISTINCT user_id)) OVER (
            PARTITION BY cohort_month 
            ORDER BY month_number
        ) as cohort_size
    FROM user_activities
    WHERE month_number IS NOT NULL
    GROUP BY cohort_month, month_number
)
SELECT 
    cohort_month,
    cohort_size,
    month_number,
    active_users,
    (active_users * 100.0 / cohort_size) as retention_rate,
    -- 전월 대비 유지율
    LAG(active_users) OVER (
        PARTITION BY cohort_month 
        ORDER BY month_number
    ) as previous_month_users,
    CASE 
        WHEN LAG(active_users) OVER (
            PARTITION BY cohort_month 
            ORDER BY month_number
        ) > 0 
        THEN (active_users * 100.0 / LAG(active_users) OVER (
            PARTITION BY cohort_month 
            ORDER BY month_number
        ))
        ELSE NULL
    END as month_over_month_retention
FROM cohort_analysis
ORDER BY cohort_month DESC, month_number;

-- 9. 검색 효율성 분석
-- 복잡한 집계, 상관관계
SELECT 
    sl.search_query,
    COUNT(DISTINCT sl.id) as search_count,
    COUNT(DISTINCT sl.user_id) as unique_searchers,
    AVG(sl.results_count) as avg_results_count,
    COUNT(DISTINCT sl.clicked_product_id) as click_count,
    (COUNT(DISTINCT sl.clicked_product_id) * 100.0 / NULLIF(COUNT(DISTINCT sl.id), 0)) as click_through_rate,
    -- 검색 후 구매 전환
    COUNT(DISTINCT CASE 
        WHEN sl.clicked_product_id IS NOT NULL THEN 
            (SELECT o.id FROM orders o 
             JOIN order_items oi ON o.id = oi.order_id 
             WHERE oi.product_id = sl.clicked_product_id 
               AND o.user_id = sl.user_id 
               AND o.created_at > sl.created_at 
             LIMIT 1)
    END) as post_click_conversions,
    -- 검색어 길이 분석
    LENGTH(sl.search_query) as query_length,
    -- 검색 시간대 분석
    EXTRACT(HOUR FROM sl.created_at) as search_hour,
    CASE 
        WHEN EXTRACT(HOUR FROM sl.created_at) BETWEEN 6 AND 11 THEN 'MORNING'
        WHEN EXTRACT(HOUR FROM sl.created_at) BETWEEN 12 AND 17 THEN 'AFTERNOON'
        WHEN EXTRACT(HOUR FROM sl.created_at) BETWEEN 18 AND 23 THEN 'EVENING'
        ELSE 'NIGHT'
    END as time_of_day
FROM search_logs sl
WHERE sl.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY 
    sl.search_query, 
    LENGTH(sl.search_query),
    EXTRACT(HOUR FROM sl.created_at),
    CASE 
        WHEN EXTRACT(HOUR FROM sl.created_at) BETWEEN 6 AND 11 THEN 'MORNING'
        WHEN EXTRACT(HOUR FROM sl.created_at) BETWEEN 12 AND 17 THEN 'AFTERNOON'
        WHEN EXTRACT(HOUR FROM sl.created_at) BETWEEN 18 AND 23 THEN 'EVENING'
        ELSE 'NIGHT'
    END
HAVING COUNT(DISTINCT sl.id) >= 10
ORDER BY search_count DESC, click_through_rate DESC
LIMIT 50;

-- 10. 복잡한 퍼널 분석
-- 여러 단계의 전환율 분석
WITH funnel_steps AS (
    -- Step 1: 제품 조회
    SELECT 
        pv.user_id,
        pv.product_id,
        'VIEW' as step,
        pv.created_at as step_time
    FROM product_views pv
    WHERE pv.created_at >= CURRENT_DATE - INTERVAL '7 days'
    
    UNION ALL
    
    -- Step 2: 장바구니 추가
    SELECT 
        ci.user_id,
        ci.product_id,
        'CART' as step,
        ci.created_at as step_time
    FROM cart_items ci
    WHERE ci.created_at >= CURRENT_DATE - INTERVAL '7 days'
    
    UNION ALL
    
    -- Step 3: 주문
    SELECT 
        o.user_id,
        oi.product_id,
        'ORDER' as step,
        o.created_at as step_time
    FROM orders o
    JOIN order_items oi ON o.id = oi.order_id
    WHERE o.created_at >= CURRENT_DATE - INTERVAL '7 days'
        AND o.status IN ('PROCESSING', 'DELIVERED')
),
user_funnel AS (
    SELECT 
        user_id,
        product_id,
        step,
        step_time,
        ROW_NUMBER() OVER (
            PARTITION BY user_id, product_id, step 
            ORDER BY step_time
        ) as step_rank
    FROM funnel_steps
),
funnel_counts AS (
    SELECT 
        step,
        COUNT(DISTINCT user_id) as unique_users,
        COUNT(DISTINCT product_id) as unique_products,
        COUNT(*) as total_events
    FROM user_funnel
    WHERE step_rank = 1  -- 각 단계의 첫 번째 이벤트만
    GROUP BY step
)
SELECT 
    step,
    unique_users,
    unique_products,
    total_events,
    -- 전 단계 대비 전환율
    LAG(unique_users) OVER (ORDER BY 
        CASE step 
            WHEN 'VIEW' THEN 1 
            WHEN 'CART' THEN 2 
            WHEN 'ORDER' THEN 3 
        END
    ) as previous_step_users,
    CASE 
        WHEN LAG(unique_users) OVER (ORDER BY 
            CASE step 
                WHEN 'VIEW' THEN 1 
                WHEN 'CART' THEN 2 
                WHEN 'ORDER' THEN 3 
            END
        ) > 0 
        THEN (unique_users * 100.0 / LAG(unique_users) OVER (ORDER BY 
            CASE step 
                WHEN 'VIEW' THEN 1 
                WHEN 'CART' THEN 2 
                WHEN 'ORDER' THEN 3 
            END
        ))
        ELSE NULL
    END as conversion_rate_from_previous,
    -- 전체 퍼널 대비 전환율
    (unique_users * 100.0 / NULLIF(
        (SELECT unique_users FROM funnel_counts WHERE step = 'VIEW'), 0
    )) as overall_conversion_rate
FROM funnel_counts
ORDER BY 
    CASE step 
        WHEN 'VIEW' THEN 1 
        WHEN 'CART' THEN 2 
        WHEN 'ORDER' THEN 3 
    END;
