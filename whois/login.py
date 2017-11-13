# Python script that web scrapes chronicle.cat.pdx.edu
# roster information.
# Copyright (c) 2017 David Kim
# This program is licensed under the "MIT License".

import requests
from bs4 import BeautifulSoup
from passwd import username, passwd

# instantiate a Session object
s = requests.Session()

# authentication url
url = "https://chronicle.cat.pdx.edu/login?back_url=https%3A%2F%2Fchronicle.cat.pdx.edu%2F"

# send an HTTP GET request
r = s.get(url)

# find the current authenticity token value
soup = BeautifulSoup(r.content, 'html.parser')
token = soup.find('input', {'name': 'authenticity_token'}).get('value')

# craft the form data
payload = {'utf8': '',
           'authenticity_token': token,
           'back_url': 'https://chronicle.cat.pdx.edu/',
           'username': 'username',
           'password': passwd}

# get the page
r = s.post(url, data=payload)
# print(r.text)

# get the roster links
urls = [line.rstrip('\n') for line in open('links')]
# print urls

# output each roster link's HTML source to files
x=0
for url in urls:
    r = s.get(url)
    soup = BeautifulSoup(r.content, 'html.parser')
    filename = "roster" + str(x)
    file = open(filename, "w")
    file.write(str(soup))
    x += 1
