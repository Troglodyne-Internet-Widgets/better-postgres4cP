function versionHandler () {
    var obj = JSON.parse(this.responseText);
    if(obj.result === 1) {
        document.getElementById('psqlVersion').innerHTML = obj.data.version.major + '.' + obj.data.version.minor;
    } else {
        console.log(obj.error);
    }
}

var oReq = new XMLHttpRequest();
oReq.addEventListener("load", versionHandler);
oReq.open("GET", "api.cgi?module=Postgres&function=get_server_version");
oReq.send();
