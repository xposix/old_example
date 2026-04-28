# Client App

## Getting started

1. If you don't have `pipenv`, you can install it using `pip`:
   
    `pip install pipenv`
   
2. Create a virtual environment using `pipenv` and python 3.10:
    
    `pipenv shell --pypthon=3.10`
   
3. Install the dependencies in the virtual environment and `pre-commit`:
   
    `pipenv install --dev && pre-commit install`
   
4. Run the app locally:

   `./start.sh`

5. To stop the app locally: 

   `./stop.sh`
   
   _Please note sometimes redis or celery servers are up and running, so once you run 
   this command check also the processes to see if they are actually killed (using ps aux | grep celery). 
   if they are up and running kill the process using_ `kill -9 PID`

6. Go to http://0.0.0.0/docs to check the app docs.
