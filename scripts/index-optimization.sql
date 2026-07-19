-- 인덱스 최적화 시나리오
-- 쿼리 튜닝을 위한 다양한 인덱스 전략

-- 1. 기본 인덱스 분석
-- 현재 인덱스 상태 확인
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename IN ('users', 'products', 'orders', 'order_items', 'product_reviews')
ORDER BY tablename, indexname;

-- 2. 인덱스 사용 통계 분석
-- 인덱스 실사용 현황 확인
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

-- 3. 미사용 인덱스 식별
-- 성능 저하 요인이 될 수 있는 미사용 인덱스 찾기
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size,
    idx_scan as index_scans
FROM pg_stat_user_indexes
WHERE idx_scan = 0
    AND indexname NOT LIKE '%_pkey'
ORDER BY pg_relation_size(indexrelid) DESC;

-- 4. 인덱스 효율성 분석
-- 인덱스 스캔 vs 시퀀셜 스캔 비교
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    seq_scan as sequential_scans,
    CASE 
        WHEN seq_scan > 0 THEN (idx_scan::float / (idx_scan + seq_scan)) * 100
        ELSE 100
    END as index_usage_percentage
FROM pg_stat_user_indexes psi
JOIN pg_stat_user_tables pst ON psi.schemaname = pst.schemaname AND psi.tablename = pst.tablename
ORDER BY index_usage_percentage ASC;

-- 5. 부분 인덱스 생성 (조건부 인덱스)
-- 활성 사용자만 위한 인덱스
CREATE INDEX CONCURRENTLY idx_users_active_email 
ON users(email) 
WHERE status = 'ACTIVE';

-- 최근 주문만 위한 인덱스
CREATE INDEX CONCURRENTLY idx_orders_recent_created 
ON orders(created_at DESC) 
WHERE created_at >= CURRENT_DATE - INTERVAL '6 months';

-- 높은 평점 리뷰만 위한 인덱스
CREATE INDEX CONCURRENTLY idx_product_reviews_high_rating 
ON product_reviews(product_id, rating DESC) 
WHERE rating >= 4 AND status = 'APPROVED';

-- 6. 함수 기반 인덱스
-- 대소문자 구분 없는 이메일 검색을 위한 인덱스
CREATE INDEX CONCURRENTLY idx_users_email_lower 
ON users(LOWER(email));

-- 이름 검색을 위한 트라이그램 인덱스 (pg_trgm 확장 필요)
-- CREATE EXTENSION IF NOT EXISTS pg_trgm;
-- CREATE INDEX CONCURRENTLY idx_products_name_trgm 
-- ON products USING GIN (name gin_trgm_ops);

-- 날짜 기반 인덱스
CREATE INDEX CONCURRENTLY idx_orders_month_year 
ON orders(EXTRACT(YEAR FROM created_at), EXTRACT(MONTH FROM created_at));

-- 7. 커버링 인덱스 (INCLUDE)
-- 쿼리 성능 최적화를 위한 커버링 인덱스
CREATE INDEX CONCURRENTLY idx_orders_user_status_include 
ON orders(user_id, status) 
INCLUDE (total_amount, created_at);

CREATE INDEX CONCURRENTLY idx_product_reviews_product_rating_include 
ON product_reviews(product_id, rating) 
INCLUDE (created_at, is_verified_purchase);

CREATE INDEX CONCURRENTLY idx_order_items_order_product_include 
ON order_items(order_id, product_id) 
INCLUDE (quantity, unit_price, total_price);

-- 8. 복합 인덱스 최적화
-- 컬럼 순서가 중요한 복합 인덱스
-- 카디널리티가 높은 컬럼부터 배치
CREATE INDEX CONCURRENTLY idx_products_category_status_price 
ON products(category_id, status, price DESC);

CREATE INDEX CONCURRENTLY idx_orders_user_status_date 
ON orders(user_id, status, created_at DESC);

CREATE INDEX CONCURRENTLY idx_product_views_product_date 
ON product_views(product_id, created_at DESC);

-- 9. GIN 인덱스 (배열 타입)
-- 태그 검색을 위한 GIN 인덱스
CREATE INDEX CONCURRENTLY idx_products_tags_gin 
ON products USING GIN (tags);

-- 선호 카테고리 검색을 위한 GIN 인덱스
CREATE INDEX CONCURRENTLY idx_user_preferences_categories_gin 
ON user_preferences USING GIN (preferred_categories);

-- 10. 해시 인덱스 (동등 비교)
-- 해시 인덱스는 동등 비교에서만 사용 가능
CREATE INDEX CONCURRENTLY idx_users_email_hash 
ON users USING HASH (email);

CREATE INDEX CONCURRENTLY idx_products_sku_hash 
ON products USING HASH (sku);

-- 11. 인덱스 유지보수
-- 인덱스 조각화 모니터링
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size,
    idx_blks_read as blocks_read,
    idx_blks_hit as blocks_hit,
    CASE 
        WHEN idx_blks_read + idx_blks_hit > 0 
        THEN (idx_blks_hit::float / (idx_blks_read + idx_blks_hit)) * 100
        ELSE 0
    END as cache_hit_ratio
FROM pg_stat_user_indexes
ORDER BY cache_hit_ratio ASC;

-- 12. 인덱스 재구성 필요성 분석
-- bloat 확인 (인덱스 조각화)
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size,
    pg_stat_get_dead_tuples(indexrelid) as dead_tuples
FROM pg_stat_user_indexes
WHERE pg_stat_get_dead_tuples(indexrelid) > 1000
ORDER BY dead_tuples DESC;

-- 13. 쿼리 플랜 분석을 위한 인덱스 힌트
-- 특정 쿼리의 실행 계획 분석
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT u.name, COUNT(o.id) as order_count
FROM users u
JOIN orders o ON u.id = o.user_id
WHERE u.status = 'ACTIVE'
    AND o.created_at >= '2024-01-01'
GROUP BY u.name
ORDER BY order_count DESC
LIMIT 10;

-- 14. 인덱스 삭제 및 재생성 전략
-- CONCURRENTLY 옵션으로 운영 중에도 인덱스 재생성 가능
-- DROP INDEX CONCURRENTLY idx_users_email;
-- CREATE INDEX CONCURRENTLY idx_users_email ON users(email);

-- 15. 파티셔닝을 위한 인덱스 전략
-- 대용량 테이블의 파티셔닝 고려
-- 예: orders 테이블을 날짜별 파티셔닝 시
-- CREATE INDEX CONCURRENTLY idx_orders_created_at ON orders(created_at);

-- 16. 통계 정보 업데이트
-- 쿼리 최적화를 위한 통계 정보 업데이트
ANALYZE users;
ANALYZE products;
ANALYZE orders;
ANALYZE order_items;
ANALYZE product_reviews;

-- 17. 자동 vacuum 설정 확인
-- autovacuum 설정 확인
SELECT 
    relname,
    autovacuum_enabled,
    autovacuum_vacuum_threshold,
    autovacuum_vacuum_scale_factor,
    autovacuum_analyze_threshold,
    autovacuum_analyze_scale_factor
FROM pg_class
WHERE relname IN ('users', 'products', 'orders', 'order_items', 'product_reviews');

-- 18. 인덱스 크기 모니터링 쿼리
-- 인덱스와 테이블 크기 비교
SELECT 
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as indexes_size,
    (pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) * 100.0 / 
    pg_total_relation_size(schemaname||'.'||tablename) as index_percentage
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- 19. 쿼리 성능 모니터링 뷰 생성
-- 자주 사용되는 쿼리 모니터링을 위한 뷰
CREATE OR REPLACE VIEW query_performance_monitor AS
SELECT 
    schemaname,
    tablename,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch,
    n_tup_ins,
    n_tup_upd,
    n_tup_del,
    n_tup_hot_upd,
    n_live_tup,
    n_dead_tup,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze,
    vacuum_count,
    autovacuum_count,
    analyze_count,
    autoanalyze_count
FROM pg_stat_user_tables
ORDER BY seq_scan DESC, idx_scan DESC;

-- 20. 인덱스 추천 시스템을 위한 분석 쿼리
-- 누락된 인덱스 추천
SELECT 
    schemaname,
    tablename,
    attname as column_name,
    n_distinct as distinct_values,
    null_frac as null_fraction,
    correlation as column_correlation
FROM pg_stats
WHERE schemaname = 'public'
    AND tablename IN ('users', 'products', 'orders', 'order_items', 'product_reviews')
    AND n_distinct > 100  -- 카디널리티가 높은 컬럼
    AND null_frac < 0.1   -- NULL이 적은 컬럼
ORDER BY n_distinct DESC;
