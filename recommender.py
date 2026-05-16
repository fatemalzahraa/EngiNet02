# recommender.py
from surprise import SVD, Dataset, Reader
from surprise.model_selection import train_test_split
import pandas as pd

def train_model(db):
    cursor = db.cursor()
    
    # جلب كل التفاعلات
    cursor.execute("""
        SELECT user_id, 
               CONCAT(content_type, '_', content_id) as item_id,
               score
        FROM user_interactions
    """)
    interactions = cursor.fetchall()
    
    if len(interactions) < 10:
        return None  # بيانات قليلة جداً
    
    df = pd.DataFrame(interactions, columns=['user_id', 'item_id', 'score'])
    
    reader = Reader(rating_scale=(1, 5))
    data = Dataset.load_from_df(df, reader)
    trainset, _ = train_test_split(data, test_size=0.2)
    
    model = SVD()
    model.fit(trainset)
    
    return model, df['item_id'].unique()