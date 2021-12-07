#!/usr/bin/env python3
from fastapi import FastAPI
from fastapi_utils.tasks import repeat_every
import logging
from fastapi.logger import logger as fastapi_logger
from pydantic import BaseModel
from typing import List, Optional, Dict
import asyncio
import aiohttp
import re
import json
import datetime
import pytz
import os
#from yarl import cache_configure
logger = logging.getLogger("repeat")
# # Console handler
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
logger.addHandler(ch)

app = FastAPI(
        title="EngAssNginx",
        description="Nginx terraform deployment",
        version="0.0.1",
        docs_url="/api/doc",
        terms_of_service="http://example.com/terms/",
        contact={
            "name": "Pieter@Github",
            "url": "https://github.com/diepes/",
            "email": "github@vigor.nz",
        },
        license_info={
            "name": "GPL 3.0",
            "url": "https://www.gnu.org/licenses/gpl-3.0.en.html",
        },
    )
 
global config
if os.path.isfile("flag-this-is-dev.txt"):
    config = {  # Developement
        "log_file":   "/var/log/monitor-nginx.log",
        "status_url": "http://52.64.137.163:81/nginx_status",
    }
else:
    config = {  # Production
        "log_file":   "/opt/gitrepo/html/resource.log",
        "status_url": "http://127.0.0.1:81/nginx-status",
    }
global counter
counter = 1

class LogMsg(BaseModel):
  date: datetime.datetime
  logmsg: dict

#class Logs(BaseModel):
#    logs: list[LogMsg]

db: List[LogMsg] = []

@app.on_event("startup")
async def loadLogs():
    logger=logging.getLogger("repeat")
    logger.setLevel(logging.INFO)
    logger.debug(f"loadLogs: started")
    linecount = 0
    if os.path.isfile(config["log_file"]):
        with open(config["log_file"], "r") as file_object:
            for line in file_object.readlines():
                if line.strip():
                    await addLogToDb(json.loads(line))
                    linecount += 1
        logger.info(f"loadLogs: Loaded {linecount} log lines len(db):{len(db)}")
    else:
        logger.warning(f"loadLogs: no log file {config['log_file']}")

async def addLogToDb(log: dict):
    # Limit in memory to 7days @10sec = 60480 entries
    maxlen = 6 * 60 * 24 * 7
    db.insert(0, LogMsg( date = log['time'], logmsg = log))    
    if len(db) > maxlen:
        del db[maxlen:]


@app.get("/api/logs")
async def fetch_logs():
    return db
       


@app.get("/")
async def root():
    return {"message": f"Hello World counter={counter}"}

async def getLogs():
    logdata = config.logdata  # List containing log lines


async def count():
    global counter
    counter = counter + 1

@app.on_event("startup")
#@repeat_every(seconds=1, logger=logger, wait_first=True)
@repeat_every(seconds=10, wait_first=False, logger=logging.getLogger("repeat"))
async def run_10s_schedule():
    logger=logging.getLogger("repeat")
    logger.setLevel(logging.INFO)
    global counter
    global config
    counter += 1
    logger.debug(  f"START log-debug run_10s_schedule!!! #{counter}")
    loop = asyncio.get_running_loop()
    task_docker = loop.create_task(getDockerStatus(name="nginx", logger=logger))
    task_nginx  = loop.create_task(getNginxStatus(status_url=config["status_url"], logger=logger))
    logger.debug( "started status retrieval coroutines")
    utc_now = pytz.utc.localize(datetime.datetime.utcnow())
    local_now = utc_now.astimezone(pytz.timezone("Pacific/Auckland"))
    status_docker = await task_docker
    status_nginx  = await task_nginx
    logger.debug( "retrieved status results")
    status = {"time": local_now.isoformat(), "docker" : status_docker, "nginx": status_nginx}
    await addLogToDb(status)
    with open(config["log_file"], "a") as file_object:
        file_object.write(json.dumps(status))
        file_object.write('\n')
    logger.debug(f"END run_10s_schedule!!! #{counter} ##{status}")


async def getDockerStatus(name: str, logger):
    # docker stats nginx   --no-stream   --format "{{ json . }}"
    procdocker,exitcode = await run(f"docker stats --no-stream {name} --format '{{{{ json . }}}}'", logger)
    docker_info = { "exitcode": exitcode, "Name": name }
    logger.debug(f"getDockerStatus ... {exitcode}")
    if exitcode == 0:
        docker_info.update(json.loads(procdocker))
    return docker_info


async def getNginxStatus(status_url: str, logger):
    async with aiohttp.ClientSession(conn_timeout=2) as session:
        try:
            async with session.get(status_url) as resp:
                nginx_text = await resp.text(encoding='ascii')
        except aiohttp.client_exceptions.ServerTimeoutError:
            response = "timeout"
        else:
            response = resp.status
        logger.debug("getNginxStatus ...")
        resp_dict = {"status": response, "url": status_url}
        if response == 200:
            nginx_dict = await parse_nginx_status(nginx_text)
            resp_dict.update(nginx_dict)
            return resp_dict
        else:
            return resp_dict


async def parse_nginx_status(status_txt: str):
    ''' example status_txt
    Active connections: 1 
    server accepts handled requests
    692 692 691 
    Reading: 0 Writing: 1 Waiting: 0 
    '''
    match = re.match(r'Active connections: (?P<active>\d+)\s*\n'+
                     r'server accepts handled requests\s*\n'+
                     r'\s*(?P<accepts>\d+)\s+(?P<handled>\d+)\s+(?P<requests>\d+)\s*\n'+
                     r'\s*Reading:\s+(?P<reading>\d+)\s+Writing:\s+(?P<writing>\d+)\s+Waiting:\s+(?P<waiting>\d+)\s*$'
                     ,status_txt
                     ,re.MULTILINE|re.DOTALL
                    )
    if match:
        return match.groupdict()
    else:
        return f"Re-Error: {status_txt}"


async def run(cmd,logger):
    proc = await asyncio.create_subprocess_shell(
        cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE)
    await asyncio.sleep(1)
    stdout, stderr = await proc.communicate()
    #print(f'[{cmd!r} exited with {proc.returncode}]')
    #if stdout:
    #    print(f'[stdout]\n{stdout.decode()}')
    if stderr:
        logger.error(f'run: [stderr] for # {cmd}\n     {stderr.decode()}')
    return stdout.decode(), proc.returncode

if __name__ == "__main__":
    import uvicorn
    print("MAIN #1!!!")
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
    print("MAIN #2!!!")