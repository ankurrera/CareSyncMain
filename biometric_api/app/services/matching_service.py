import math
import numpy as np
from typing import List

def calibrate_match_confidence(similarity: float) -> float:
    """
    Calibrates raw cosine similarity to a match probability percentage using Sigmoid calibration.
    """
    k = 15.0
    x0 = 0.55
    p = 1.0 / (1.0 + math.exp(-k * (similarity - x0)))
    return round(p * 100.0, 2)

def get_adaptive_max_distance(quality_score: float) -> float:
    """
    Retrieves the adaptive pgvector match distance (1 - similarity threshold) based on image quality.
    """
    if quality_score >= 0.85:
        return 0.32 # High Quality: strict (similarity >= 0.68)
    elif quality_score >= 0.65:
        return 0.38 # Medium Quality: relaxed (similarity >= 0.62)
    else:
        return 0.40 # Low Quality: relaxed (similarity >= 0.60)

def l2_normalize(vector: List[float]) -> List[float]:
    arr = np.array(vector)
    norm = np.linalg.norm(arr)
    if norm == 0:
        return vector
    return (arr / norm).tolist()
