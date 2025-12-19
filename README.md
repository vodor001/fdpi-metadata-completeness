# FDPcrawleR
Metadata Completeness check for FAIR Data Point index of ERDERA Virtual Platform 

This R-script checks the completeness of DCAT-structured metadata of all the active FDPs in the VP Index. 
The script implements a web-crawler for FDPs, using the VP index URL as an entry point and DCAT-2 and FDP Ontology (FDP-O) terms to navigate in the hierarchical metadata structure. Its final goal is to quantify how many FDPs have metadata at different levels of the FDP metadata hierarchy iteratively going from Index to FDPs, from FDPs to Catalogs, from Catalogs to Datasets, and finally, from Datasets to Distributions. 
The results of the analysis are visualized as a Sankey diagram. 

# The overview (corresponds to the comment numbers in the code): 

1. The script starts with querying the VP Index API, parsing the JSON response, retaining only “ACTIVE” FDPs, and normalizing their URLs to avoid duplicates. 

2. An empty RDF graph is initialized, and each active FDP is linked to the index via an artificial http://example.org/hasFdp predicate to create the root of the metadata graph. 

3. Further,  fetch_turtle() funcion is created to retrieve RDF descriptions in Turtle format.

4. The script then iterates through all FDP URLs, fetching and parsing their metadata into the shared RDF graph. After this step, the graph contains both Index->FDP relations and all FDP-level metadata.

5. Using a generic SPARQL query, the graph is extracted into an R dataframe of triples for further processing.

6. To discover catalogs, the script filters triples using the FDP Ontology (FDP-O) term fdp-o:metadataCatalog, producing FDP->Catalog progression.

7-8. Catalog URLs are normalized and crawled in the same manner as FDPs: fetching Turtle, parsing new triples, adding them to the graph, and updating the dataframe. 

9. Next, datasets are identified by filtering triples containing dcat:dataset as the predicate. 

10. Extracted dataset URLs are normalized and then scraped.

11. This step enriches the RDF graph with dataset-level metadata.

12. Finally, distributions are discovered by filtering triples using dcat:distribution. A distribution Turtle contains a triple with an actionable access point (file, API, Beacon endpoint). 
Distribution URLs are extracted and normalized, but not further crawled, as the goal is simply to verify their presence.

13. Using the mappings FDP->Catalog, Catalog->Dataset, and Dataset->Distribution, the script computes key completeness metrics: FDPs with at least one catalog, FDPs whose catalogs contain at least one dataset, FDPs whose datasets expose at least one distribution. Complementary sets (FDPs with catalogs but no datasets) are also calculated. 
The script concludes by generating a Sankey diagram summarizing how FDPs progress through the metadata hierarchy—from being registered in the Index to exposing catalogs, datasets, and distributions. This visualization provides an immediate overview of the maturity and functional readiness of the FDP Index.
