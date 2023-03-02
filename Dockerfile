# Build variables. These need to be declared befored the first FROM
# for the variables to be accessible in FROM instruction.
ARG BLAST_VERSION=2.12.0

## Stage 1: gem dependencies.
FROM ruby:2.7-slim-buster AS builder

# Copy over files required for installing gem dependencies.
WORKDIR /sequenceserver
COPY wurmlab_sequenceserver/Gemfile wurmlab_sequenceserver/Gemfile.lock wurmlab_sequenceserver/sequenceserver.gemspec ./
COPY wurmlab_sequenceserver/lib/sequenceserver/version.rb lib/sequenceserver/version.rb

# Install packages required for building gems with C extensions.
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc make patch && rm -rf /var/lib/apt/lists/*

# Install gem dependencies using bundler.
RUN bundle install --without=development

## Stage 2: BLAST+ binaries.
# We will copy them from NCBI's docker image.
FROM ncbi/blast:${BLAST_VERSION} AS ncbi-blast

## Stage 3: Puting it together.
FROM ruby:2.7-slim-buster AS final

LABEL Description="Intuitive local web frontend for the BLAST bioinformatics tool"
LABEL MailingList="https://groups.google.com/forum/#!forum/sequenceserver"
LABEL Website="http://sequenceserver.com"

# Install packages required to run SequenceServer and BLAST.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl libgomp1 liblmdb0 && rm -rf /var/lib/apt/lists/*

# Copy gem dependencies and BLAST+ binaries from previous build stages.
COPY --from=builder /usr/local/bundle/ /usr/local/bundle/
COPY --from=ncbi-blast /blast/lib /blast/lib/
COPY --from=ncbi-blast /blast/bin/blast_formatter /blast/bin/
COPY --from=ncbi-blast /blast/bin/blastdbcmd /blast/bin/
COPY --from=ncbi-blast /blast/bin/blastn.REAL /blast/bin/blastn
COPY --from=ncbi-blast /blast/bin/blastp.REAL /blast/bin/blastp
COPY --from=ncbi-blast /blast/bin/blastx.REAL /blast/bin/blastx
COPY --from=ncbi-blast /blast/bin/makeblastdb /blast/bin
COPY --from=ncbi-blast /blast/bin/tblastn.REAL /blast/bin/tblastn
COPY --from=ncbi-blast /blast/bin/tblastx.REAL /blast/bin/tblastx

# Add BLAST+ binaries to PATH.
ENV PATH=/blast/bin:${PATH}

# Setup working directory, volume for databases, port, and copy the code.
# SequenceServer code.
WORKDIR /sequenceserver
VOLUME ["/db"]
EXPOSE 4567
EXPOSE 3000
COPY wurmlab_sequenceserver/ .

# Generate config file with default configs and database directory set to /db.
# Setting database directory in config file means users can pass command line
# arguments to SequenceServer without having to specify -d option again.
RUN mkdir -p /db && echo 'n' | script -qfec "bundle exec bin/sequenceserver -s -d /db" /dev/null 

# Prevent SequenceServer from prompting user to join announcements list.
RUN mkdir -p ~/.sequenceserver && touch ~/.sequenceserver/asked_to_join

# Run of Local_BLAST_Server
RUN mkdir /local_blast_server
WORKDIR /local_blast_server
RUN apt-get update && apt-get -y --no-install-recommends install git
RUN git clone https://github.com/hmizobata/Local_blast_server2.git
COPY command.sh Local_blast_server2/
WORKDIR /db
RUN mkdir db_nucl db_prot
COPY sample_H.sapiens_mitochondrial.fasta db_nucl/
WORKDIR /db/db_nucl
RUN /blast/bin/makeblastdb -dbtype nucl -in sample_H.sapiens_mitochondrial.fasta -parse_seqids
WORKDIR /local_blast_server/Local_blast_server2
COPY makeconfig.sh makeconfig.sh
RUN apt-get install -y npm
RUN npm install

# Add SequenceServer's bin directory to PATH and set ENTRYPOINT to
# 'bundle exec'. Combined, this simplifies passing command-line
# arguments to SequenceServer, while retaining the ability to run
# bash in the container.
WORKDIR /sequenceserver
ENV PATH=/sequenceserver/bin:${PATH}
CMD ["bash", "-c", "bash /local_blast_server/Local_blast_server2/command.sh ${seqserver_url} && tail -f /dev/null"]

## Stage 4 (optional) minify CSS & JS.
FROM node:15-alpine3.12 AS node

RUN apk add --no-cache git
WORKDIR /usr/src/app
COPY wurmlab_sequenceserver/package.json .
RUN npm install
ENV PATH=${PWD}/node_modules/.bin:${PATH}
COPY wurmlab_sequenceserver/public public
RUN npm run-script build

## Stage 5 (optional) minify
FROM final AS minify

COPY --from=node /usr/src/app/public/sequenceserver-*.min.js public/
COPY --from=node /usr/src/app/public/css/sequenceserver.min.css public/css/

FROM final

