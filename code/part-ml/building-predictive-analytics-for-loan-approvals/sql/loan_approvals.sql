CREATE DATABASE IF NOT EXISTS loans_db;

USE loans_db;

-- Loan status distribution for train_data table
SELECT
    LoanStatus,
    COUNT(*) AS TotalLoans,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()), 2) AS Percentage
FROM train_data
GROUP BY LoanStatus;

-- Loan status distribution for test_data table
SELECT
    LoanStatus,
    COUNT(*) AS TotalLoans,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()), 2) AS Percentage
FROM test_data
GROUP BY LoanStatus;

-- Average loan amount by home ownership
SELECT
    CASE
        WHEN HomeOwnership_mortgage = 1 THEN 'Mortgage'
        WHEN HomeOwnership_other = 1 THEN 'Other'
        WHEN HomeOwnership_own = 1 THEN 'Own'
        WHEN HomeOwnership_rent = 1 THEN 'Rent'
    END AS HomeOwnership,
    ROUND(AVG(LoanAmount), 2) AS AvgLoanAmount
FROM train_data
GROUP BY HomeOwnership
ORDER BY AvgLoanAmount DESC;

-- Average interest rate by loan purpose
SELECT
    CASE
        WHEN LoanPurpose_car = 1 THEN 'Car'
        WHEN LoanPurpose_credit_card = 1 THEN 'Credit Card'
        WHEN LoanPurpose_debt_consolidation = 1 THEN 'Debt Consolidation'
        WHEN LoanPurpose_home_improvement = 1 THEN 'Home Improvement'
        WHEN LoanPurpose_major_purchase = 1 THEN 'Major Purchase'
        WHEN LoanPurpose_medical = 1 THEN 'Medical'
        WHEN LoanPurpose_other = 1 THEN 'Other'
        WHEN LoanPurpose_small_business = 1 THEN 'Small Business'
        WHEN LoanPurpose_vacation = 1 THEN 'Vacation'
        WHEN LoanPurpose_wedding = 1 THEN 'Wedding'
    END AS LoanPurpose,
    ROUND(AVG(InterestRate), 2) AS AvgInterestRate
FROM train_data
GROUP BY LoanPurpose
ORDER BY AvgInterestRate DESC;

-- Loan distribution by loan purpose and term
SELECT
    CASE
        WHEN LoanPurpose_car = 1 THEN 'Car'
        WHEN LoanPurpose_credit_card = 1 THEN 'Credit Card'
        WHEN LoanPurpose_debt_consolidation = 1 THEN 'Debt Consolidation'
        WHEN LoanPurpose_home_improvement = 1 THEN 'Home Improvement'
        WHEN LoanPurpose_major_purchase = 1 THEN 'Major Purchase'
        WHEN LoanPurpose_medical = 1 THEN 'Medical'
        WHEN LoanPurpose_other = 1 THEN 'Other'
        WHEN LoanPurpose_small_business = 1 THEN 'Small Business'
        WHEN LoanPurpose_vacation = 1 THEN 'Vacation'
        WHEN LoanPurpose_wedding = 1 THEN 'Wedding'
    END AS LoanPurpose,
    CASE
        WHEN Term_36 = 1 THEN 36
        WHEN Term_60 = 1 THEN 60
    END AS TermMonths,
    COUNT(*) AS NumberOfLoans
FROM train_data
GROUP BY LoanPurpose, TermMonths
ORDER BY TermMonths, NumberOfLoans DESC;

SELECT
    CASE
        WHEN LoanPurpose_car = 1 THEN 'Car'
        WHEN LoanPurpose_credit_card = 1 THEN 'Credit Card'
        WHEN LoanPurpose_debt_consolidation = 1 THEN 'Debt Consolidation'
        WHEN LoanPurpose_home_improvement = 1 THEN 'Home Improvement'
        WHEN LoanPurpose_major_purchase = 1 THEN 'Major Purchase'
        WHEN LoanPurpose_medical = 1 THEN 'Medical'
        WHEN LoanPurpose_other = 1 THEN 'Other'
        WHEN LoanPurpose_small_business = 1 THEN 'Small Business'
        WHEN LoanPurpose_vacation = 1 THEN 'Vacation'
        WHEN LoanPurpose_wedding = 1 THEN 'Wedding'
    END AS LoanPurpose,
    SUM(CASE WHEN Term_36 = 1 THEN 1 ELSE 0 END) AS Term_36_Months,
    SUM(CASE WHEN Term_60 = 1 THEN 1 ELSE 0 END) AS Term_60_Months
FROM train_data
GROUP BY LoanPurpose
ORDER BY LoanPurpose;

-- Correlation between numerical features
SELECT
    ROUND((
        AVG(AnnualIncome * LoanAmount) - AVG(AnnualIncome) * AVG(LoanAmount)
    ) / (
        STDDEV(AnnualIncome) * STDDEV(LoanAmount)
    ), 4) AS Correlation_Coefficient
FROM train_data;

-- Feature importance by loan status
SELECT
    LoanStatus,
    ROUND(AVG(DebtToIncome), 2) AS AvgDebtToIncome
FROM train_data
GROUP BY LoanStatus;

-- Outlier Detection; find loans where the amount is more than 50% of annual income
SELECT
    AnnualIncome,
    LoanAmount,
    ROUND(LoanAmount / AnnualIncome, 4) AS LoanToIncomeRatio
FROM train_data
WHERE (LoanAmount / AnnualIncome) > 0.5
ORDER BY LoanToIncomeRatio DESC
LIMIT 10;
