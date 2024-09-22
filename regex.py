import re

# Sample IEEE citation
ieee_citation = '''K. Dou, Y. Wang, Q. Yang, Y. Han and Z. Yang, "Research on Mainstream DataBase Security Analysis Technology of Big Data Platform," 2021 IEEE 21st International Conference on Software Quality, Reliability and Security Companion (QRS-C), Hainan, China, 2021, pp. 994-998, doi: 10.1109/QRS-C55045.2021.00150.'''

def ieee_to_apa(ieee_citation):
    # Step 1: Extract authors
    author_pattern = r"([A-Z]\. [A-Za-z]+(?:,| and))"
    authors = re.findall(author_pattern, ieee_citation)
    
    if not authors:
        raise ValueError("Error: Unable to extract authors from the citation.")
    
    # Reformat authors for APA
    authors = [f"{a.split()[1]}, {a.split()[0][0]}." for a in authors]
    formatted_authors = ', '.join(authors).replace(', and', ' &')
    
    # Step 2: Extract title
    title_pattern = r'".+?"'
    title_match = re.search(title_pattern, ieee_citation)
    
    if not title_match:
        raise ValueError("Error: Unable to extract title from the citation.")
    
    title = title_match.group().strip('"')
    title = title[0].upper() + title[1:].lower()
    title = re.sub(r'\b[a-z]', lambda m: m.group().upper(), title, count=1)
    
    # Step 3: Extract conference details
    conf_pattern = r'\d{4} IEEE .+? \(\w+\)'  # Adjusted regex for better matching
    conference_match = re.search(conf_pattern, ieee_citation)
    
    if not conference_match:
        raise ValueError("Error: Unable to extract conference details from the citation.")
    
    conference = conference_match.group()
    conference_apa = f"In {conference}"
    
    # Step 4: Extract DOI and format it
    doi_pattern = r'doi: (10\.\d{4,}/[^\s]+)'
    doi_match = re.search(doi_pattern, ieee_citation)
    
    if not doi_match:
        raise ValueError("Error: Unable to extract DOI from the citation.")
    
    doi = doi_match.group(1)
    doi_url = f"https://doi.org/{doi}"
    
    # Step 5: Format year and page numbers
    year_pattern = r'(\d{4}), pp\. (\d+-\d+)'
    year_match = re.search(year_pattern, ieee_citation)
    
    if not year_match:
        raise ValueError("Error: Unable to extract year and page numbers from the citation.")
    
    year, pages = year_match.groups()
    
    # Construct APA citation
    apa_citation = f"{formatted_authors} ({year}). {title}. {conference_apa}, (pp. {pages}). {doi_url}"
    
    return apa_citation

# Test the function
print(ieee_to_apa(ieee_citation))

