import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans

# Load customer-level RFM data
df = pd.read_csv("data/cleaned/customer_segments.csv")

print(df.head())
print("\nShape:")
print(df.shape)

print("\nRFM summary:")
print(df[["recency", "frequency", "monetary"]].describe())

rfm = df[
    ["recency", "frequency", "monetary"]
].copy()

print("\nRFM features:")
print(rfm.head())

import numpy as np

# Log-transform RFM variables to reduce skewness
rfm_log = np.log1p(rfm)

# Standardize the transformed features
scaler = StandardScaler()
rfm_scaled = scaler.fit_transform(rfm_log)

print("\nScaled RFM:")
print(rfm_scaled[:5])

from sklearn.cluster import KMeans

kmeans_3 = KMeans(
    n_clusters=3,
    random_state=42,
    n_init=10
)

cluster_3 = kmeans_3.fit_predict(rfm_scaled)

df["cluster_3"] = cluster_3

print("\n3-cluster counts:")
print(df["cluster_3"].value_counts().sort_index())

inertias = []
k_values = range(2, 8)

for k in k_values:
    model = KMeans(
        n_clusters=k,
        random_state=42,
        n_init=10
    )

    model.fit(rfm_scaled)

    inertias.append(model.inertia_)

    plt.figure(figsize=(8, 5))

plt.plot(
    list(k_values),
    inertias,
    marker="o"
)

plt.title("KMeans Elbow Method")
plt.xlabel("Number of Clusters (K)")
plt.ylabel("Inertia")

plt.tight_layout()
plt.show()

kmeans_3 = KMeans(
    n_clusters=3,
    random_state=42,
    n_init=10
)

kmeans_4 = KMeans(
    n_clusters=4,
    random_state=42,
    n_init=10
)

df["cluster_3"] = kmeans_3.fit_predict(rfm_scaled)
df["cluster_4"] = kmeans_4.fit_predict(rfm_scaled)

print("\n3-cluster sizes:")
print(df["cluster_3"].value_counts().sort_index())

print("\n4-cluster sizes:")
print(df["cluster_4"].value_counts().sort_index())

cluster_profile_4 = (
    df.groupby("cluster_4")[
        ["recency", "frequency", "monetary"]
    ]
    .mean()
    .round(2)
)

print("\n4-cluster profile:")
print(cluster_profile_4)

comparison = pd.crosstab(
    df["segment"],
    df["cluster_4"]
)

print("\nRFM Segment vs KMeans Cluster:")
print(comparison)

comparison_pct = pd.crosstab(
    df["segment"],
    df["cluster_4"],
    normalize="index"
) * 100

print("\nRFM Segment vs KMeans Cluster (%):")
print(comparison_pct.round(2))

plt.figure(figsize=(10, 6))

sns.heatmap(
    comparison_pct,
    annot=True,
    fmt=".1f",
    cmap="Blues"
)

plt.title("RFM Segments vs KMeans Clusters")
plt.xlabel("KMeans Cluster")
plt.ylabel("RFM Segment")

plt.tight_layout()
plt.show()

cluster_business_profile = (
    df.groupby("cluster_4")
      .agg(
          customers=("CustomerID", "count"),
          avg_recency=("recency", "mean"),
          avg_frequency=("frequency", "mean"),
          avg_monetary=("monetary", "mean"),
          total_revenue=("monetary", "sum")
      )
      .round(2)
)

print("\nCluster business profile:")
print(cluster_business_profile)

cluster_business_profile["revenue_share_pct"] = (
    cluster_business_profile["total_revenue"]
    / cluster_business_profile["total_revenue"].sum()
    * 100
).round(2)

print("\nCluster business profile:")
print(cluster_business_profile)

df.to_csv(
    "data/cleaned/customer_segments_kmeans.csv",
    index=False
)

cluster_business_profile.to_csv(
    "data/cleaned/kmeans_cluster_profile.csv"
)

comparison.to_csv(
    "data/cleaned/rfm_vs_kmeans_counts.csv"
)

comparison_pct.to_csv(
    "data/cleaned/rfm_vs_kmeans_percent.csv"
)

print("\nKMeans analysis files saved.")