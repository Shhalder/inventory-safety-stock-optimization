#Data Ingestion Pipeline


#Importing necessary libraries
import pandas as pd #data manipulation
import numpy as np #numerical operations
import os #navigate computer's folders
import sqlite3 #database operations

#Data configuration
DATA_FOLDER = 'data/' # all files related to data will be stored in this folder
DB_NAME = 'inventory.db'  #database name


def load_db():
    conn = sqlite3.connect(DB_NAME) #establishing connection to the database
    print(f"Connected to {DB_NAME}")
    
    load_files = [files for files in os.listdir(DATA_FOLDER) if files.endswith(".csv")]#list all .csv files in the data folder
    
    for file in load_files:
        file_path=os.path.join(DATA_FOLDER,file) #get full path of the file so Python can find it

        if os.path.exists(file_path): #check if the file exists
          
          table_name= file.replace('.csv','').replace('_dataset','') #derive table name from file name (filename without .csv and _dataset)

          #Read CSV file into DataFrame
          df= pd.read_csv(file_path)
          df.to_sql(table_name,conn,if_exists='replace',index=False,method='multi',chunksize=10_000)

          print(f"Loaded {file} into table {table_name}")

        else:
           print(f"File{file_path} does not exist.")

    conn.close() #close the connection

if __name__ == "__main__":
    load_db()