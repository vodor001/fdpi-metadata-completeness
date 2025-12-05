# fdpi-metadata-completeness
Metadata Completeness check for FAIR Data Point index of ERDERA Virtual Platform 

This R-script checks the completeness of DCAT-structured metadata of all the active FDPs in the VP Index. 
The script implements a web-crawler for FDPs, using the VP index URL as an entry point and DCAT-2 and FDP Ontology (FDP-O) terms to navigate in the hierarchical metadata structure. Its final goal is to quantify how many FDPs have metadata at different levels of the FDP metadata hierarchy iteratively going from Index to FDPs, from FDPs to Catalogs, from Catalogs to Datasets, and finally, from Datasets to Distributions. 
The results of the analysis are visualized as a Sankey diagram. 
