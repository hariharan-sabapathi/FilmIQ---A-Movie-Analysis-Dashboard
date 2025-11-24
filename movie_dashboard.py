import pandas as pd
import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
import networkx as nx
import duckdb
import numpy as np
from scipy.stats import gaussian_kde
import base64

# -------------------------------------------------------
# PAGE CONFIG
# -------------------------------------------------------
st.set_page_config(page_title="FilmIQ -- A Movie Analysis Dashboard", page_icon="🎬", layout="wide")
st.title("🎬 FilmIQ -- A Movie Analysis Dashboard")

# -------------------------------------------------------
# BACKGROUND IMAGE
# -------------------------------------------------------

def set_bg(image_path):
    with open(image_path, "rb") as image_file:
        encoded = base64.b64encode(image_file.read()).decode()

    st.markdown(
        f"""
        <style>
        .stApp {{
            background-image: url("data:image/jpeg;base64,{encoded}");
            background-size: cover;
            background-position: center;
            background-repeat: no-repeat;
        }}
        </style>
        """,
        unsafe_allow_html=True
    )

set_bg(r"D:\DMQL\Project\DATASET\zip\Background.png")

# -------------------------------------------------------
# LOAD DATA
# -------------------------------------------------------
@st.cache_data
def load_data():
    imdb = pd.read_csv("imdb_final.csv")
    osc = pd.read_csv("oscars_final.csv")

    imdb.columns = imdb.columns.str.strip()
    osc.columns = osc.columns.str.strip()

    imdb["movie_name_clean"] = imdb["movie_name"].str.lower().str.strip()
    osc["movie_name_clean"] = osc["Film"].astype(str).str.lower().str.strip()

    duckdb.register("imdb", imdb)
    duckdb.register("osc", osc)

    merged = duckdb.query("""
        SELECT *
        FROM imdb
        LEFT JOIN osc
        ON imdb.movie_name_clean = osc.movie_name_clean
    """).df()

    def clean_winner(val):
        if pd.isna(val):
            return 0
        s = str(val).strip().lower()
        if s in ("true", "1", "yes", "y"):
            return 1
        if s in ("false", "0", "no", "n", ""):
            return 0
        if ("true" in s) or ("win" in s) or ("1" in s):
            return 1
        return 0

    if "Winner" in merged.columns:
        merged["Winner"] = merged["Winner"].apply(clean_winner).astype(int)

    return merged


df = load_data()

# -------------------------------------------------------
# SIDEBAR NAVIGATION
# -------------------------------------------------------
st.sidebar.title("Navigation")
page = st.sidebar.radio("Go To", ["Overview", "Movie Details", "Directors", "Actors"])

# -------------------------------------------------------
# FILTERS
# -------------------------------------------------------
st.sidebar.header("Filters")

year_min = int(df["year"].min())
year_max = int(df["year"].max())

year_range = st.sidebar.slider("Year Range", year_min, year_max, (2000, year_max))
min_rating = st.sidebar.slider("Minimum Rating", 0.0, 10.0, 7.0)

all_genres = sorted(set(",".join(df["genre"].astype(str)).replace(" ", "").split(",")))
selected_genres = st.sidebar.multiselect("Genres", all_genres)
only_winners = st.sidebar.checkbox("Only Oscar Winners")

# -------------------------------------------------------
# APPLY FILTERS
# -------------------------------------------------------

def filter_sql():
    where = f"""
        year BETWEEN {year_range[0]} AND {year_range[1]}
        AND rating >= {min_rating}
    """

    if selected_genres:
        genre_clause = " OR ".join([f"genre LIKE '%{g}%'" for g in selected_genres])
        where += f" AND ({genre_clause})"

    if only_winners:
        where += " AND Winner = 1"

    sql = f"""
        SELECT *
        FROM df
        WHERE {where}
    """

    duckdb.register("df", df)
    return duckdb.query(sql).df()


df_filtered = filter_sql()

# -------------------------------------------------------
# OVERVIEW PAGE
# -------------------------------------------------------
if page == "Overview":
    st.header("Overview")

    c1, c2, c3, c4 = st.columns(4, gap="large")
    c1.metric("Movies", len(df_filtered))
    c2.metric("Avg Rating", round(df_filtered["rating"].mean(), 2))
    c3.metric("Total Votes", f"{df_filtered['votes'].sum():,}")
    c4.metric("Oscar Wins", int(df_filtered["Winner"].sum()))

    st.subheader("Rating Distribution: Oscar Winners vs Non-Winners")

    # Use FILTERED dataset so graph changes with sidebar filters
    duckdb.register("filtered", df_filtered)

    ratings_joined = duckdb.query("""
        SELECT DISTINCT
            movie_name_clean,
            CAST(rating AS DOUBLE) AS rating,
            CASE 
                WHEN Winner = 1 THEN 'Oscar Winner'
                ELSE 'Non-Winner'
            END AS win_status
        FROM filtered
        WHERE rating IS NOT NULL
    """).df()


    winners = ratings_joined[ratings_joined["win_status"] == "Oscar Winner"]["rating"]
    non_winners = ratings_joined[ratings_joined["win_status"] == "Non-Winner"]["rating"]

    fig = go.Figure()

    if len(winners) > 2:
        kde_win = gaussian_kde(winners)
        xw = np.linspace(winners.min(), winners.max(), 200)
        fig.add_trace(go.Scatter(
            x=xw,
            y=kde_win(xw),
            mode="lines",
            fill="tozeroy",
            name="Oscar Winners",
            line=dict(width=3)
        ))

    if len(non_winners) > 2:
        kde_non = gaussian_kde(non_winners)
        xn = np.linspace(non_winners.min(), non_winners.max(), 200)
        fig.add_trace(go.Scatter(
            x=xn,
            y=kde_non(xn),
            mode="lines",
            fill="tozeroy",
            name="Non-Winners",
            line=dict(width=3)
        ))

    fig.update_layout(
        height=500,
        margin=dict(l=40, r=40, t=10, b=40),
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        font=dict(color="white"),
        xaxis=dict(title="Rating", gridcolor="rgba(255,255,255,0.05)"),
        yaxis=dict(title="Density", gridcolor="rgba(255,255,255,0.05)")
    )

    st.plotly_chart(fig, use_container_width=True)

    st.markdown("---")

    # ---------- Oscar Wins per Year ----------
    st.subheader("Oscar Wins per Year")

    duckdb.register("filtered", df_filtered)

    oscars_yearly = duckdb.query("""
        SELECT
            year,
            COUNT(DISTINCT movie_name_clean) AS oscar_wins
        FROM filtered
        WHERE Winner = 1
        AND year IS NOT NULL
        GROUP BY year
        ORDER BY year
    """).df()

    fig = px.line(
        oscars_yearly,
        x="year",
        y="oscar_wins",
        markers=True,
        labels={
            "year": "Year",
            "oscar_wins": "Number of Oscar-Winning Movies"
        },
    )

    fig.update_layout(
        margin=dict(l=40, r=40, t=15, b=40),
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        font=dict(color="white"),
        xaxis=dict(gridcolor="rgba(255,255,255,0.05)"),
        yaxis=dict(gridcolor="rgba(255,255,255,0.05)")
    )

    st.plotly_chart(fig, use_container_width=True)

    st.markdown("---")

# GRAPH 3
    st.subheader("Oscar Success Rate by Genre")

    # Prevent 100% issue when Only Oscar Winners is checked
    df_genre_base = df_filtered if not only_winners else df.copy()
    duckdb.register("filtered_for_genre", df_genre_base)

    if selected_genres:
        genre_condition = "WHERE genre IN ({})".format(
            ",".join([f"'{g}'" for g in selected_genres])
        )
        genre_limit = len(selected_genres)
    else:
        genre_condition = ""
        genre_limit = 10

    genre_oscar_df = duckdb.query(f"""
    WITH exploded AS (
        SELECT
            movie_name_clean,
            TRIM(g) AS genre,
            Winner
        FROM filtered_for_genre
        CROSS JOIN UNNEST(STRING_SPLIT(genre, ',')) AS t(g)
        WHERE genre IS NOT NULL
    )
    SELECT
        genre,
        COUNT(DISTINCT movie_name_clean) AS total_movies,
        COUNT(DISTINCT CASE WHEN Winner = 1 THEN movie_name_clean END) AS oscar_winners,
        ROUND(
            (COUNT(DISTINCT CASE WHEN Winner = 1 THEN movie_name_clean END) * 100.0)
            / COUNT(DISTINCT movie_name_clean), 2
        ) AS success_rate
    FROM exploded
    {genre_condition}
    GROUP BY genre
    ORDER BY success_rate DESC
    LIMIT {genre_limit}
    """).df()


    fig = px.bar(
        genre_oscar_df,
        x="success_rate",
        y="genre",
        orientation="h",
        text="success_rate",
        hover_data={
            "total_movies": True,
            "oscar_winners": True
        },
        labels={
            "success_rate": "Oscar Success Rate (%)",
            "genre": "Genre"
        },
    )

    fig.update_traces(
        marker_color="#A5CFEA",
        texttemplate="%{text}%",
        textposition="outside"
    )

    fig.update_layout(
        height=550,
        margin=dict(l=40, r=40, t=15, b=40),
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        font=dict(color="white"),
        xaxis=dict(gridcolor="rgba(255,255,255,0.05)"),
        yaxis=dict(title=""),
        showlegend=False
    )

    st.plotly_chart(fig, use_container_width=True)

    st.markdown("---")

# -------------------------------------------------------
# MOVIE DETAILS PAGE
# -------------------------------------------------------
elif page == "Movie Details":
    st.header("Search Movies")

    query = st.text_input("Enter movie name")

    if query:
        duckdb.register("df", df)

        # --- SAFE SEARCH QUERY ---
        sql = """
            SELECT DISTINCT movie_id, movie_name, year, rating, votes
            FROM df
            WHERE LOWER(movie_name) LIKE ?
            ORDER BY rating DESC
        """
        results = duckdb.execute(sql, [f"%{query.lower()}%"]).df()

        st.dataframe(results)

        if len(results) > 0:

            results["display"] = results.apply(
                lambda x: f"{x['movie_name']} ({x['year']})", axis=1
            )

            movie_map = dict(zip(results["display"], results["movie_id"]))

            selected_display = st.selectbox(
                "Select movie",
                options=list(movie_map.keys()),
                key="movie_selector"
            )

            selected_movie_id = movie_map[selected_display]

            # ---- MOVIE DETAILS ----
            sql_detail = """
                SELECT *
                FROM df
                WHERE movie_id = ?
                LIMIT 1
            """
            row = duckdb.execute(sql_detail, [selected_movie_id]).df().iloc[0]

            st.subheader(row["movie_name"])
            st.write("Year:", row["year"])
            st.write("Rating:", row["rating"])
            st.write("Genres:", row.get("genre", "N/A"))
            st.write("Director:", row.get("director", "N/A"))
            st.write("Stars:", row.get("star", "N/A"))

            # ---- OSCAR WINS ----
            sql_awards = """
                SELECT CanonicalCategory, Category, Year
                FROM df
                WHERE movie_id = ? AND Winner = 1
            """
            awards = duckdb.execute(sql_awards, [selected_movie_id]).df()

            if len(awards) > 0:
                st.write("🏆 Oscars Won:")
                for _, a in awards.iterrows():
                    cat = a.get("CanonicalCategory") or a.get("Category")
                    st.write(f"- **{cat}**")
            else:
                st.write("No Oscar wins recorded.")


# -------------------------------------------------------
# DIRECTORS PAGE
# -------------------------------------------------------
elif page == "Directors":
    st.header("Director Overview")
    duckdb.register("filtered", df_filtered)

    # =========================
    # DIRECTOR SUMMARY STATS
    # =========================
    sql_directors = """
        SELECT director,
            COUNT(DISTINCT movie_id) AS movies,
            ROUND(AVG(rating), 2) AS avg_rating,
            SUM(votes) AS total_votes,
            SUM(Winner) AS oscar_wins
        FROM filtered
        GROUP BY director
        ORDER BY avg_rating DESC
    """

    directors_df = duckdb.query(sql_directors).df()
    st.dataframe(directors_df)


    # =========================
    # SAFE DIRECTOR SELECTOR (FIXED)
    # =========================

    directors_df["display"] = directors_df.apply(
        lambda x: f"{x['director']}", axis=1
    )

    director_map = dict(zip(directors_df["display"], directors_df["director"]))

    selected_display = st.selectbox(
        "Select director",
        options=list(director_map.keys()),
        key="director_selector"
    )

    selected_director = director_map[selected_display]

    # =========================
    # MOVIES BY DIRECTOR
    # =========================
    st.subheader(f"Movies by {selected_director}")

    sql_movies = """
        SELECT DISTINCT movie_name, year, rating
        FROM filtered
        WHERE director = ?
        ORDER BY year DESC
    """
    movies = duckdb.execute(sql_movies, [selected_director]).df()
    st.dataframe(movies)

    # GRAPH - Most Prolific Directors
    st.subheader("Top Rated Directors")

    sql_top_directors = """
        SELECT director,
            ROUND(AVG(rating), 2) AS avg_rating,
            COUNT(DISTINCT movie_id) AS total_movies
        FROM filtered
        GROUP BY director
        HAVING COUNT(DISTINCT movie_id) >= 2
        ORDER BY avg_rating DESC
        LIMIT 10
    """

    top_directors_df = duckdb.query(sql_top_directors).df()

    fig = px.bar(
        top_directors_df,
        x="director",
        y="avg_rating",
        text="avg_rating",
        hover_data={
            "total_movies": True
        },
        labels={
            "avg_rating": "Average Rating",
            "director": "Director"
        },
    )

    fig.update_traces(
        marker_color="#A5CFEA",
        texttemplate="%{text}",
        textposition="outside"
    )

    fig.update_layout(
        height=550,
        margin=dict(l=40, r=40, t=15, b=80),
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        font=dict(color="white"),
        xaxis=dict(
            title="",
            tickangle=-30,
            gridcolor="rgba(255,255,255,0.05)"
        ),
        yaxis=dict(
            title="Average Rating",
            gridcolor="rgba(255,255,255,0.05)",
            range=[
                top_directors_df["avg_rating"].min() - 0.1,
                top_directors_df["avg_rating"].max() + 0.1
            ]
        ),
        showlegend=False
    )

    st.plotly_chart(fig, use_container_width=True)
    st.markdown("---")

# -------------------------------------------------------
# ACTORS PAGE
# -------------------------------------------------------
elif page == "Actors":
    st.header("Actor Overview")

    # Use FILTERED dataset so it reacts to sidebar filters
    duckdb.register("filtered", df_filtered)

    # =========================
    # ACTOR SUMMARY TABLE
    # =========================
    sql_actors = """
        WITH exploded AS (
            SELECT
                movie_id,
                movie_name,
                year,
                rating,
                votes,
                Winner,
                TRIM(actor) AS actor
            FROM filtered
            CROSS JOIN UNNEST(STRING_SPLIT(star, ',')) AS t(actor)
            WHERE star IS NOT NULL
        )
        SELECT
            actor,
            COUNT(DISTINCT movie_id) AS movies,
            ROUND(AVG(rating), 2) AS avg_rating,
            SUM(votes) AS total_votes,
            SUM(Winner) AS oscar_wins
        FROM exploded
        GROUP BY actor
    """

    actors_df = duckdb.query(sql_actors).df()
    st.dataframe(actors_df)

    # =========================
    # ACTOR SELECTOR
    # =========================

    actors_df["display"] = actors_df["actor"]
    actor_map = dict(zip(actors_df["display"], actors_df["actor"]))

    selected_display = st.selectbox(
        "Select actor",
        options=list(actor_map.keys()),
        key="actor_selector"
    )

    selected_actor = actor_map[selected_display]

    # =========================
    # MOVIES BY ACTOR
    # =========================
    st.subheader(f"Movies featuring {selected_actor}")

    sql_actor_movies = """
        WITH exploded AS (
            SELECT
                movie_name,
                year,
                rating,
                TRIM(actor) AS actor
            FROM filtered
            CROSS JOIN UNNEST(STRING_SPLIT(star, ',')) AS t(actor)
        )
        SELECT DISTINCT
            movie_name,
            year,
            rating
        FROM exploded
        WHERE actor = ?
        ORDER BY year DESC
    """

    actor_movies_df = duckdb.execute(sql_actor_movies, [selected_actor]).df()
    st.dataframe(actor_movies_df)


    # =========================
    # ACTOR OSCAR PERFORMANCE
    # =========================
    st.subheader("Oscar Wins by Actor")

    sql_actor_oscars = """
        WITH exploded AS (
            SELECT
                movie_id,
                Winner,
                TRIM(actor) AS actor
            FROM filtered
            CROSS JOIN UNNEST(STRING_SPLIT(star, ',')) AS t(actor)
        )
        SELECT
            actor,
            COUNT(DISTINCT movie_id) AS total_movies,
            SUM(Winner) AS oscar_wins
        FROM exploded
        GROUP BY actor
        ORDER BY oscar_wins DESC
        LIMIT 10
    """

    actor_oscars_df = duckdb.query(sql_actor_oscars).df()

    fig2 = px.bar(
        actor_oscars_df,
        x="actor",
        y="oscar_wins",
        text="oscar_wins",
        hover_data={"total_movies": True},
        labels={
            "actor": "Actor",
            "oscar_wins": "Oscar Wins"
        }
    )

    fig2.update_traces(
        marker_color="#A5CFEA",
        texttemplate="%{text}",
        textposition="outside"
    )

    fig2.update_layout(
        height=500,
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        font=dict(color="white"),
        xaxis=dict(tickangle=-30),
        showlegend=False
    )

    st.plotly_chart(fig2, use_container_width=True)
    st.markdown("---")