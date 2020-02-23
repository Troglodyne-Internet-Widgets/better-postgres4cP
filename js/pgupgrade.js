function versionHandler () {
    'use strict';
    let obj = JSON.parse(this.responseText);
    if(obj.result === 1) {

        // Construct version warning/display
        let pgVersion = obj.data.installed_version.major + '.' + obj.data.installed_version.minor;
        let elem = document.getElementById('psqlVersion');
        let html = pgVersion;
        if( parseFloat(pgVersion) < parseFloat(obj.data.minimum_supported_version) ) {
            elem.classList.add('callout', 'callout-danger');
            html += " -- You are using a version of PostgreSQL Server that is no longer supported! Immediate upgrade reccomended.";
        }
        elem.innerHTML = html;

        // Now let's build the table
        let rows = '';
        for ( var version of Object.keys(obj.data.available_versions) ) {
            rows +=
`<tr id="pgVersionRow-${version}">
    <td>
        <input type="radio" name="selectedVersion" value="${version}"></input>
        ${version}
    </td>
    <td>
        Lorem Ipsum
    </td>
    <td>
        Community
    </td>
    <td>
        ${obj.data.available_versions[version].release}
    </td>
    <td>
        ${obj.data.available_versions[version].EOL}
    </td>
</tr>`;
        }
        document.querySelector('#upgradeForm > table > tbody').innerHTML = rows;
    } else {
        console.log(obj.error);
    }
}

var oReq = new XMLHttpRequest();
oReq.addEventListener("load", versionHandler);
oReq.open("GET", "api.cgi?module=Postgres&function=get_postgresql_versions");
oReq.send();
