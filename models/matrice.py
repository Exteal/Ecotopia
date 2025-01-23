import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

# Charger les fichiers CSV
agriculture = pd.read_csv('data_agricultural_plot.csv')
urbanism = pd.read_csv('data_urbanisme_plot.csv')
energy = pd.read_csv('data_energy_plot.csv')
transport = pd.read_csv('data_transport_plot.csv')

# Remplir les valeurs 'nil' par 0 ou NaN, puis les convertir en float
def clean_data(df):
    return df.replace('nil', np.nan).fillna(0).astype(float)

agriculture = clean_data(agriculture)
urbanism = clean_data(urbanism)
energy = clean_data(energy)
transport = clean_data(transport)

# 1. Calcul des données liées à l'énergie
# Production totale d'énergie
total_production_energy = energy[[
    "tick_production_E'hydro_energy'",
    "tick_production_E'nuclear_energy'",
    "tick_production_E'solar_energy'",
    "tick_production_E'wind_energy'"
]].sum(axis=1)

# Consommation totale d'énergie par tous les secteurs
total_consumption_energy = pd.concat([
    transport["tick_pop_consumption_T'any_energy'"],
    urbanism["global_tick_resources_usage'any_energy'"]
], axis=1).sum(axis=1)

# Calcul des émissions de chaque secteur
emissions_agriculture = agriculture["tick_emissions_A'gCO2e emissions'"]
emissions_urbanism = urbanism["global_tick_emissions'gCO2e emissions'"]
emissions_energy = energy[[
    "tick_emissions_E'hydro_energy'",
    "tick_emissions_E'nuclear_energy'",
    "tick_emissions_E'solar_energy'",
    "tick_emissions_E'wind_energy'"
]].sum(axis=1)

# 2. Création de la matrice de flux
flux_matrix = pd.DataFrame(index=["Énergie", "Émissions"],
                           columns=["Transport", "Urbanisme", "Agriculture", "Fournisseur Énergie"])

# Remplir la ligne pour l'énergie (production et consommation)
flux_matrix.loc["Énergie", "Transport"] = transport["tick_pop_consumption_T'any_energy'"].mean()
flux_matrix.loc["Énergie", "Urbanisme"] = urbanism["global_tick_resources_usage'any_energy'"].mean()
flux_matrix.loc["Énergie", "Fournisseur Énergie"] = (total_production_energy - total_consumption_energy).mean()

# Remplir la ligne pour les émissions
flux_matrix.loc["Émissions", "Agriculture"] = emissions_agriculture.mean()
flux_matrix.loc["Émissions", "Urbanisme"] = emissions_urbanism.mean()
flux_matrix.loc["Émissions", "Fournisseur Énergie"] = emissions_energy.mean()

# Convertir les types de données en float et remplacer NaN par 0
flux_matrix = flux_matrix.apply(pd.to_numeric, errors='coerce').fillna(0)

# Visualisation de la matrice de flux
plt.figure(figsize=(12, 6))
sns.heatmap(flux_matrix, annot=True, fmt='.2f', cmap='coolwarm', cbar=True)

# Ajouter des étiquettes et un titre
plt.title('Matrice EM')
plt.xlabel('Secteurs')
plt.ylabel('Flux')
plt.tight_layout()

# Afficher la matrice
plt.show()
