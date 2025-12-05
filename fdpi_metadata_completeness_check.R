library(httr)
library(rdflib)
library(dplyr)
library(plotly)

res <- GET(
  "https://index.vp.ejprarediseases.org/index/entries/all",
  add_headers(Accept = "*/*")
)

txt <- content(res, as = "text", encoding = "UTF-8")
fdp_df <- jsonlite::fromJSON(txt, flatten = TRUE)

fdp_active <- fdp_df %>%
  filter(state == "ACTIVE")

fdp_active_list_raw <- fdp_active$clientUrl  # list of FDP-URL

#normalize all URLs - control "/" at the end - delete them

normalize_url <- function(x) {
  x <- sub("/+$", "", x)  
  x <- sub(":7070$", "", x)
  x
}

fdp_active_list <- normalize_url(fdp_active_list_raw)

#2==================

g_all <- rdf()

index_uri   <- "https://index.vp.ejprarediseases.org/index/"
pred_hasFdp <- "http://example.org/hasFdp"

for (fdp in fdp_active_list) {
  rdf_add(
    g_all,
    subject   = index_uri,
    predicate = pred_hasFdp,
    object    = fdp
  )
}


#3==========================================

fetch_turtle <- function(url) {
  message("  Fetching: ", url)
  
  out <- tryCatch(
    {
      res <- httr::GET(
        url,
        httr::timeout(10),              # longer timeout is possible
        httr::add_headers(Accept = "text/turtle")
      )
      
      if (httr::status_code(res) >= 400) {
        message("  HTTP error ", httr::status_code(res), " for ", url)
        return(NA_character_)
      }
      
      txt <- httr::content(res, as = "text", encoding = "UTF-8")
      if (!nzchar(txt)) {
        message("  Empty body from ", url)
        return(NA_character_)
      }
      
      txt
    },
    error = function(e) {
      message("  FETCH ERROR for ", url, " : ", e$message)
      return(NA_character_)
    }
  )
  
  out
}


#4===========================

fdp_failed <- character()  # for FDPs that cannot be parsed

for (fdp_url in fdp_active_list) {
  message("-----")
  message("Processing FDP: ", fdp_url)
  
  turtle_txt <- fetch_turtle(fdp_url)
  if (is.na(turtle_txt)) {
    fdp_failed <- c(fdp_failed, fdp_url)
    next
  }
  
  # adding new turtle to the graph
  tryCatch(
    {
      g_all <- rdf_parse(
        doc    = turtle_txt,
        format = "turtle",
        rdf    = g_all
      )
    },
    error = function(e) {
      message("  Parse error: ", e$message)
      fdp_failed <- c(fdp_failed, fdp_url)
    }
  )
}

#5=======================================

df_triples <- rdf_query(
  g_all,
  'SELECT ?s ?p ?o WHERE { ?s ?p ?o }'
)

#6======================================

P_METADATA_CATALOG <- "https://w3id.org/fdp/fdp-o#metadataCatalog"

fdp_to_catalog <- df_triples %>%
  filter(p == P_METADATA_CATALOG) %>%
  transmute(
    fdp     = s,
    catalog = o
  ) %>%
  distinct()

catalog_urls_raw <- unique(fdp_to_catalog$catalog)
catalog_urls <- normalize_url(catalog_urls_raw)
#7==========================================

catalog_failed <- character()

for (cat_url in catalog_urls) {
  message("-----")
  message("Processing Catalog: ", cat_url)
  
  # Try to fetch turtle
  turtle_txt <- fetch_turtle(cat_url)
  
  # If fetch_turtle() failed - no dataset for this catalog
  if (is.na(turtle_txt)) {
    message("  Cannot fetch catalog RDF — marking as having NO datasets.")
    next
  }
  
  # Try to parse and add to RDF graph
  tryCatch(
    {
      g_all <- rdf_parse(
        doc    = turtle_txt,
        format = "turtle",
        rdf    = g_all
      )
    },
    error = function(e) {
      message("  Parse error: ", e$message)
      catalog_failed <- c(catalog_failed, cat_url)
      next
    }
  )
}

#8====================================
df_triples <- rdf_query(
  g_all,
  'SELECT ?s ?p ?o WHERE { ?s ?p ?o }'
) %>% 
  distinct()

#9====================================
#let's find dataset URLs

P_DCAT_DATASET <- "http://www.w3.org/ns/dcat#dataset"

catalog_to_dataset <- df_triples %>%
  filter(p == P_DCAT_DATASET) %>%
  transmute(
    catalog = s,
    dataset = o
  ) %>%
  distinct()

dataset_urls_raw <- unique(catalog_to_dataset$dataset)

dataset_urls <- normalize_url(dataset_urls_raw)
#10=====================================

dataset_failed <- character()
for (dat_url in dataset_urls) {
  message("-----")
  message("Processing Dataset: ", dat_url)
  
  # Try to fetch turtle
  turtle_txt <- fetch_turtle(dat_url)
  
  # If fetch_turtle() failed → no dataset for this catalog
  if (is.na(turtle_txt)) {
    message("  Cannot fetch dataset RDF — marking as having NO distributions.")
    dataset_failed <- c(dataset_failed, dat_url)
    next
  }
  
  # Try to parse and add to RDF graph
  tryCatch(
    {
      g_all <- rdf_parse(
        doc    = turtle_txt,
        format = "turtle",
        rdf    = g_all
      )
    },
    error = function(e) {
      message("  Parse error: ", e$message)
      dataset_failed <- c(dataset_failed, dat_url)
      next
    }
  )
}

#11=============================

df_triples <- rdf_query(
  g_all,
  'SELECT ?s ?p ?o WHERE { ?s ?p ?o }'
) %>% 
  distinct()

#12=======================================
#let's find distribution URLs
P_DCAT_DISTRIBUTION <- "http://www.w3.org/ns/dcat#distribution"

dataset_to_distribution <- df_triples %>%
  filter(p == P_DCAT_DISTRIBUTION) %>%
  transmute(
    dataset     = s,
    distribution = o
  ) %>%
  distinct()

distribution_urls_raw <- unique(dataset_to_distribution$distribution)
distribution_urls <- normalize_url(distribution_urls_raw)
#13===========================================
#Calculations for the plot

# all FDP
all_fdp <- unique(fdp_active_list)
n_all <- length(all_fdp)

# FDP with at least 1 Catalog
fdp_with_catalog <- fdp_to_catalog %>%
  distinct(fdp) %>%
  pull(fdp)

# FDP without Catalog
fdp_without_catalog <- setdiff(all_fdp, normalize_url(fdp_with_catalog))

# FDP with at least one dataset
fdp_with_dataset <- fdp_to_catalog %>%
  inner_join(catalog_to_dataset, by = "catalog") %>%
  distinct(fdp) %>%
  pull(fdp)

# FDP with Catalog, but without Dataset
fdp_with_catalog_no_dataset <- setdiff(fdp_with_catalog, fdp_with_dataset)

# FDP with at least one Distribution
datasets_with_distribution <- dataset_to_distribution %>%
  distinct(dataset) %>%
  pull(dataset)

fdp_with_distribution <- fdp_to_catalog %>%
  inner_join(catalog_to_dataset,  by = "catalog") %>%
  filter(dataset %in% datasets_with_distribution) %>%
  distinct(fdp) %>%
  pull(fdp)

# FDP with Dataset, but without Distribution
fdp_with_dataset_no_distribution <- setdiff(fdp_with_dataset, fdp_with_distribution)

n_cat_yes    <- length(fdp_with_catalog)
n_cat_no     <- length(fdp_without_catalog)

n_ds_yes     <- length(fdp_with_dataset)
n_ds_no      <- length(fdp_with_catalog_no_dataset)

n_dist_yes   <- length(fdp_with_distribution)
n_dist_no    <- length(fdp_with_dataset_no_distribution)

#plotting

nodes <- data.frame(
  name = c(
    paste0("All FDP (n = ", n_all, ")"),
    paste0("FDP with Catalog (n = ", n_cat_yes, ")"),
    paste0("FDP without Catalog (n = ", n_cat_no, ")"),
    paste0("FDP with Dataset (n = ", n_ds_yes, ")"),
    paste0("FDP without Dataset (n = ", n_ds_no, ")"),
    paste0("FDP with Distribution (n = ", n_dist_yes, ")"),
    paste0("FDP without Distribution (n = ", n_dist_no, ")")
  )
)

#Explicit node positions (0–1 range)
node_x <- c(
  0.00,  # All FDP
  0.33,  # FDP with Catalog
  1.00,  # FDP without Catalog
  0.66,  # FDP with Dataset
  1.00,  # FDP without Dataset
  1.00,  # FDP with Distribution
  1.00   # FDP without Distribution
)

node_y <- c(
  0.5,   # All FDP (middle)
  0.75,   # FDP with Catalog      (lower branch)
  0.25,   # FDP without Catalog   (upper branch)
  0.85,   # FDP with Dataset      (lower branch)
  0.70,   # FDP without Dataset   (upper branch)
  1.00,   # FDP with Distribution (lower branch)
  0.95    # FDP without Distribution (upper branch)
)

links <- data.frame(
  source = c(0, 0, 1, 1, 3, 3),
  target = c(1, 2, 3, 4, 5, 6),
  value  = c(
    n_cat_yes,   # All FDP -> FDP with Catalog
    n_cat_no,    # All FDP -> FDP without Catalog
    n_ds_yes,    # FDP with Catalog -> FDP with Dataset
    n_ds_no,     # FDP with Catalog -> FDP without Dataset
    n_dist_yes,  # FDP with Dataset -> FDP with Distribution
    n_dist_no    # FDP with Dataset -> FDP without Distribution
  )
)

fig <- plot_ly(
  type = "sankey",
  orientation = "h",
  node = list(
    label = nodes$name,
    pad = 15,
    thickness = 20,
    x = node_x,
    y = node_y
  ),
  link = list(
    source = links$source,
    target = links$target,
    value  = links$value
  )
)

fig
