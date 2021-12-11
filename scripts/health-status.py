#!/usr/bin/env python3
from fastapi import FastAPI, Path, Query
from fastapi.encoders import jsonable_encoder
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
import time
import pytz
import os
import pathlib
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
        #root_path="/api",  #prefixes to incoming request e.g / becomes /api
        openapi_url="/api/openapi.json",
        #terms_of_service="http://example.com/terms/",
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
        "log_file":   "../html/resource.log",
        "status_url": "http://127.0.0.1:81/nginx_status",
    }
else:
    config = {  # Production
        "log_file":   "/opt/gitrepo/html/resource.log",
        "status_url": "http://127.0.0.1:81/nginx-status",
    }
# Count 10s runs
global counter
counter = 0

class LogMsg(BaseModel):
  #t: datetime.datetime
  t: int
  log: dict

#class Logs(BaseModel):
#    logs: list[LogMsg]

db: List[LogMsg] = []


@app.on_event("startup")
async def loadLogs():
    logger=logging.getLogger("repeat")
    logger.setLevel(logging.INFO)
    logger.debug(f"loadLogs: started")
    linecount = 0
    path = pathlib.Path( config["log_file"] ).resolve()
    if os.path.isfile(path):
        with open(path, "r") as file_object:
            for line in file_object.readlines():
                if line.strip():
                    j = json.loads(line)
                    await addLogToDb(j["t"],j["log"] , insert = False) #Logs read from old to new
                    linecount += 1
        logger.info(f"loadLogs: Loaded {linecount} log lines len(db):{len(db)} from {path}")
    else:
        logger.warning(f"loadLogs: no log file {config['log_file']} -> {path}")


async def addLogToDb(t: datetime.datetime, log: dict, insert: bool = True):
    # Limit in memory to 7days @10sec = 60480 entries
    maxlen = 6 * 60 * 24 * 7
    newlog = LogMsg( t = t, log = log)
    if insert:
        db.insert(0, newlog)
    else:
        db.append(newlog)

    if len(db) > maxlen:
        del db[maxlen:]
    # return json, for new records we write to log file
    return jsonable_encoder(newlog)


@app.get("/api/logs/")
async def fetch_logs():
    return db
@app.get("/api/logs/{count}")
async def fetch_count_logs(
              count: int = Path(..., title="Number of logs"),
              ):
        return db[:count]       


@app.get("/api/logs/searchregex/{regex}")
async def log_search_regex(
              regex: str = Path(..., title='Slow Regex search e.g. "2021-12-08T21"')
):
        r = re.compile(regex)
        tempdb: List[LogMsg] = []
        for l in db:
            if r.findall(json.dumps(l.logmsg)):
                tempdb.append(l)
        return tempdb


@app.get("/api/logs/search/{fld}/{regex}")
async def log_search_path(
              fld: str = Path(..., title="Field to search e.g. docker.CPUPerc"),
              regex: str = Path(..., title="Regex e.g. 0.00")
):
    r = re.compile(regex)
    tempdb: List[LogMsg] = []
    for l in db:
        fldvalue = await find(fld,l.logmsg)
        if fldvalue:
            if r.findall(fldvalue):
                tempdb.append(l)
    return tempdb

@app.get("/api/logs/searchtime/")
async def log_search_time(start: int = 0, end: int = 0):
    filtered = []
    for l in db:
        if l.t > start and l.t < end:
            filtered.append(l)
    return filtered


async def find(key: str, value: dict) -> str:
    for k, v in value.items():
        if k == key:
            return v
        elif isinstance(v, dict):
            result = find(key, v)
            return result
        else:
          return None


async def time_str(delta: int, brief=True):
        hours, remainder = divmod(delta, 3600)
        minutes, seconds = divmod(remainder, 60)
        days, hours = divmod(hours, 24)
        if not brief:
            if days:
                fmt = '{d} days, {h} hours, {m} minutes, and {s} seconds'
            else:
                fmt = '{h} hours, {m} minutes, and {s} seconds'
        else:
            fmt = '{h}h {m}m {s}s'
            if days:
                fmt = '{d}d ' + fmt
        return fmt.format(d=int(days), h=int(hours), m=int(minutes), s=int(seconds)) 


@app.get("/")
@app.head("/")
@app.get("/api")
@app.head("/api")
@app.head("/api/")
@app.get("/api/")
async def root():
    ''' Used by LB for health check, add head to ensure 200
    '''
    TOKEN_TTL_SECONDS = 21600
    TOKEN_HEADER = "X-aws-ec2-metadata-token"
    TOKEN_HEADER_TTL = "X-aws-ec2-metadata-token-ttl-seconds"
    metadata_url = "http://169.254.169.254/latest/meta-data"
    url = f"{metadata_url}/instance-id"
    async with aiohttp.ClientSession(conn_timeout=2) as session:
        try:
            async with session.get(url) as resp:
                text = await resp.text(encoding='ascii')
        except aiohttp.client_exceptions.ServerTimeoutError:
            response = "timeout"
        except aiohttp.client_exceptions.ClientConnectorError:
            response = "connection-error"
        else:
            response = resp.status
        logger.debug("getEC2MetaData ...")
        resp_dict = {"status": response,
                     "uptime": await time_str(time.clock_gettime(time.CLOCK_BOOTTIME)),
                     "logs_generated": counter,
                    }
        if response == 200:
            resp_dict.update({"instance-id": text})
        else:
            resp_dict.update({"url": url})
    return resp_dict


@app.get("/api/update-website")
async def api_update_website():
    (procdocker,exitcode) = await run("/opt/gitrepo/scripts/cron.sh", logger=logging.getLogger("repeat"))
    #procdocker,exitcode = await run(f"docker stats --no-stream {name} --format '{{{{ json . }}}}'", logger)
    return f"Looking for update to website  ... exit={exitcode} {procdocker}"


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
    log = {"timestamp": local_now , "docker" : status_docker, "nginx": status_nginx}
    newlog = await addLogToDb(int(utc_now.timestamp()), log)
    path = pathlib.Path( config["log_file"] ).resolve()
    with open(path, "a") as file_object:
        file_object.write(json.dumps(newlog))
        file_object.write('\n')
    logger.debug(f"END run_10s_schedule!!! #{counter} ##{newlog}")


async def getDockerStatus(name: str, logger):
    # docker stats nginx   --no-stream   --format "{{ json . }}"
    (procdocker,exitcode) = await run(f"docker stats --no-stream {name} --format '{{{{ json . }}}}'", logger)
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
        except aiohttp.client_exceptions.ClientConnectorError:
            response = "connection-error"
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
        return (stderr.decode(), proc.returncode)
    return (stdout.decode(), proc.returncode)


if __name__ == "__main__":
    import uvicorn
    print("MAIN #1!!!")
    uvicorn.run(app, host="0.0.0.0", port=82, log_level="info")
    print("MAIN #2!!!")