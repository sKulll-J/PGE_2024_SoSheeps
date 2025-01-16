# Algorithme de Ray-Casting

L'algorithme de ray-casting est une méthode utilisée pour déterminer si un point donné se trouve à l'intérieur ou à l'extérieur d'un polygone. Cet algorithme est fréquemment utilisé en infographie et en géométrie numérique pour divers types de tests de point dans le polygone.

## Principe

Un rayon imaginaire est tracé à partir du point donné dans une direction quelconque (habituellement vers la droite) jusqu'à l'infini.
On compte le nombre d'intersections entre le rayonnement et les côtés du polygone:

- Si le nombre d'intersections est **impair**, le point est à l'intérieur du polygone.
- Si le nombre d'intersections est **pair**, le point est à l'extérieur du polygone.

### Exemple Visuel

Considérons un point P et un polygone avec des sommets définis dans un ordre spécifique (horaire ou antihoraire). Le rayon part de P vers la droite.

P•-------------------------------------->
                    _______
                   /       \
                  /         \
                 /           \
                /_____________\

## Étapes en Détail

### Tracer le Rayon

Dessinez un rayon horizontal partant de P jusqu'à l'infini vers la droite.

### Intersections

Identifiez où le rayon intersecte les côtés du polygone.

### Comptage

Impair : Si le rayon croise les côtés du polygone un nombre impair de fois, alors le point P est à l'intérieur.
Pair : Si le rayon croise les côtés du polygone un nombre pair de fois, alors le point P est à l'extérieur.

### Exemples

#### À l'intérieur

                    _______
                  /  P•----X----------->      
                 /          \
                /            \
               /______________\
Le rayon coupe les côtés du polygone 1 fois (impair), donc P est à l'intérieur.

#### À l'extérieur

                     _______
                    /       \
                   /         \
     P•-----------X-----------X--------->
                 /_____________\
Le rayon coupe les côtés du polygone 2 fois (pair), donc P est à l'extérieur.

### Avantages

Simplicité : Facile à comprendre et à implémenter.
Efficacité : Fonctionne bien pour les polygones convexes et concaves.
