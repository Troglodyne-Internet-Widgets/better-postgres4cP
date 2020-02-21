function versionHandler () {
    'use strict';
    let obj = JSON.parse(this.responseText);
    if(obj.result === 1) {
        let pgVersion = obj.data.installed_version.major + '.' + obj.data.installed_version.minor;
        let elem = document.getElementById('psqlVersion');
        let html = pgVersion;
        if( parseFloat(pgVersion) < parseFloat(obj.data.minimum_supported_version) ) {
            elem.classList.add('callout', 'callout-danger');
            html += " -- You are using a version of PostgreSQL Server that is no longer supported! Immediate upgrade reccomended.";
        }
        elem.innerHTML = html;
    } else {
        console.log(obj.error);
    }
}

var oReq = new XMLHttpRequest();
oReq.addEventListener("load", versionHandler);
oReq.open("GET", "api.cgi?module=Postgres&function=get_postgresql_versions");
oReq.send();
