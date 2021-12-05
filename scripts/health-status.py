#!/usr/bin/env python3
from fastapi import FastAPI
from fastapi_utils.tasks import repeat_every
import asyncio
import aiohttp
import re
import json
#import logging
import datetime
import pytz
#from yarl import cache_configure
#logging.basicConfig(level=logging.INFO)
app = FastAPI()
 
global config
config = {
    #"log_file": "/opt/gitrepo/html/resource.log",
    #status_url: "http://127.0.0.1:81/nginx-status",
    "log_file":   "/var/log/monitor-nginx.log",
    "status_url": "http://52.64.137.163:81/nginx_status",
}
global counter
counter = 1

@app.get("/")
async def root():
    return {"message": f"Hello World counter={counter}"}

async def count():
    global counter
    counter = counter + 1

@app.on_event("startup")
#@repeat_every(seconds=1, logger=logger, wait_first=True)
@repeat_every(seconds=10, wait_first=True)
async def run_10s_schedule(config=config):
    global counter
    counter += 1
    print(f"START run_10s_schedule!!! #{counter}")
    loop = asyncio.get_running_loop()
    task_docker = loop.create_task(getDockerStatus(name="nginx"))
    task_nginx  = loop.create_task(getNginxStatus(status_url=config["status_url"]))
    #
    utc_now = pytz.utc.localize(datetime.datetime.utcnow())
    local_now = utc_now.astimezone(pytz.timezone("Pacific/Auckland"))
    status_docker = await task_docker
    status_nginx  = await task_nginx
    status = {"time": local_now.isoformat(), "docker" : status_docker, "nginx": status_nginx}
    with open(config["log_file"], "a") as file_object:
        file_object.write(json.dumps(status))
        file_object.write('\n')
    print(f"END run_10s_schedule!!! #{counter} ##{status}")


async def getDockerStatus(name: str):
    # docker stats nginx   --no-stream   --format "{{ json . }}"
    procdocker,exitcode = await run(f"docker stats --no-stream {name} --format '{{{{ json . }}}}'")
    docker_info = { "exitcode": exitcode }
    if exitcode == 0:
        docker_info.update(json.loads(procdocker))
    return docker_info


async def getNginxStatus(status_url: str):
    async with aiohttp.ClientSession() as session:
        async with session.get(status_url) as resp:
            nginx_text = await resp.text(encoding='ascii')
        resp_dict = {"status": resp.status, "url": status_url}
        if resp.status == 200:
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


async def run(cmd):
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
        print(f'[stderr]\n{stderr.decode()}')
    return stdout.decode(), proc.returncode

if __name__ == "__main__":
    import uvicorn
    print("MAIN #1!!!")
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
    print("MAIN #2!!!")