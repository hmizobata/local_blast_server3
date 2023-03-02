#!/bin/bash

echo '{
  "filetypes": {
      "permitted_filetypes_upload":"[.](fasta|fa|fsa|fna|aa)([.]gz|)$",
      "permitted_filetypes_list":"[.](fasta|fa|fsa|fna|aa)($|[.])",
      "permitted_extensions":"^(fasta|fa|fsa|fna|aa)$"
  },
  "path": {
      "makeblastdbplace":"/blast/bin/makeblastdb",
      "dbplace":"/db/",
      "dbdna":"/db/db_nucl/",
      "dbprotein":"/db/db_prot/",
      "tmpplace":"/local_blast_server/local_blast_server/tmp/",
      "uploadplace":"./uploads/",
      "errorplace":"/local_blast_server/local_blast_server/error/"
  },
  "url": {';

echo '"seqserver":"'$1'"}}'
