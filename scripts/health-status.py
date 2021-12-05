#!/usr/bin/env python3
from fastapi import FastAPI
from fastapi_utils.tasks import repeat_every
import asyncio
import aiohttp
import logging
logging.basicConfig(level=logging.DEBUG)
app = FastAPI()
 
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
async def run_10s_schedule():
    global counter
    counter += 1
    loop = asyncio.get_running_loop()
    task_docker = loop.create_task(getDockerStatus(name="nginx"))
    task_nginx  = loop.create_task(getNginxStatus(url="http://127.0.0.1:81/nginx-status"))

    status_docker = await task_docker
    print(f"END run_10s_schedule!!! #{counter} #{status_docker}")
    status_nginx  = await task_nginx

    print(f"END run_10s_schedule!!! #{counter} #{status_docker} #{status_nginx}")


async def getDockerStatus(name: str):
    # docker stats nginx   --no-stream   --format "{{ json . }}"
    print("DockerOK-start")
    procdocker,returncode = await run(f"docker stats --no-stream {name} --format '{{{{ json . }}}}'")
    print("DockerOK-done")
    if returncode == 0:
        return f"DockerOK:{procdocker}"
    else:
        return "DockerErr:"


async def getNginxStatus(url: str):
    print("NginxOK-start")
    async with aiohttp.ClientSession() as session:
        status_url = 'http://127.0.0.1:81/nginx_status'
        async with session.get(status_url) as resp:
            nginx_status = await resp.json()
            print(nginx_status)
    status = '''Active connections: 1 
server accepts handled requests
 692 692 691 
Reading: 0 Writing: 1 Waiting: 0 
'''
    print("NginxOK-end")
    return "Nginx ok"

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