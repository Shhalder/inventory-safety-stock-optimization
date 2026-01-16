import _sqlite3
import pandas as pd 
import os
import numpy as np


#Path configurations
BASE_DIR=os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT= os.path.dirname(BASE_DIR)

DATA_FOLDER=os.path.join(PROJECT_ROOT, 'data')
db_path = os.path.join(DATA_FOLDER, 'inventory.db')
safety_stock_path= os.path.join(PROJECT_ROOT,'sql','calculate_safety_stock.sql')

#opens a SQL file and loads its contents into a Python string
with open(safety_stock_path, 'r') as file:  #opening the SQL file in read mode
    sql_query = file.read() #reading the entire sql query as a string 


conn= _sqlite3.connect(db_path)
df_safety_stock=pd.read_sql(sql_query,conn) #converting the sql query result into a pandas dataframe
conn.close()

print(df_safety_stock.head())

 # Risk Score : The Risk Score is a normalized, weighted metric (0.0 to 1.0) that quantifies the probability and impact of inventory failure.

 #Normalized Lead time variance 
lt_min=df_safety_stock['lead_time_variance'].min()
lt_max=df_safety_stock['lead_time_variance'].max()
df_safety_stock['normalized_lt_variance']= (df_safety_stock['lead_time_variance'] - lt_min)/(lt_max -lt_min)

 #Coefficient of Variation (CV) = demand variance/ Mean daily demand

df_safety_stock['cv_demand_variance'] = np.where(df_safety_stock['avg_daily_demand']>0, df_safety_stock['demand_variance']/df_safety_stock['avg_daily_demand'],0)
 #Normalized CV
cv_variance_min=df_safety_stock['cv_demand_variance'].min()
cv_variance_max=df_safety_stock['cv_demand_variance'].max()
df_safety_stock['normalized_cv_demand_variance'] = (df_safety_stock['cv_demand_variance'] - cv_variance_min) / (cv_variance_max - cv_variance_min)

#Risk Score Calculation
weight1=0.7
weight2=0.3
df_safety_stock['risk_index'] = (weight1 * df_safety_stock['normalized_lt_variance'])+(weight2* df_safety_stock['normalized_cv_demand_variance'])

print(df_safety_stock[['product_category_name','lead_time_variance','normalized_lt_variance','cv_demand_variance','normalized_cv_demand_variance','risk_index']].head())

#sort_by_risk
df_safety_stock= df_safety_stock.sort_values(by= 'risk_index', ascending=False)

#categories 
bins=[0,0.3,0.6,1.0]
labels=['Stable','At Risk','Critical']
df_safety_stock['risk_level'] = pd.cut(df_safety_stock['risk_index'],bins=bins,labels=labels)

#print(df_safety_stock.head())
#print(df.safety_stock[300:350])

df_safety_stock.to_csv(os.path.join(DATA_FOLDER,'inventory_risk_analysis.csv'), index=False)
