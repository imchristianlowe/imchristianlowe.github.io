FROM python:latest

RUN apt-get update -y && apt-get upgrade -y

RUN apt-get install graphviz -y

RUN python -m venv /venv

ENV PATH=/venv/bin:$PATH

RUN pip3 install diagrams

RUN mkdir /diagrams

WORKDIR /diagrams