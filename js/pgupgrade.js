function versionHandler () {
    'use strict';
    let obj = JSON.parse(this.responseText);
    if(obj.result === 1) {

        // Construct version warning/display
        let pgVersion = obj.data.installed_version.major + '.' + obj.data.installed_version.minor;
        let elem = document.getElementById('psqlVersion');
        let html = `<strong>${pgVersion}</strong>`;
        if( parseFloat(pgVersion) < parseFloat(obj.data.minimum_supported_version) ) {
            elem.classList.add('callout', 'callout-danger');
            html += " -- You are using a version of PostgreSQL Server that is no longer supported! Immediate upgrade reccomended.";
        }
        elem.innerHTML = html;

        // Now let's build the table
        let rows = '';
        for ( var version of Object.keys(obj.data.available_versions).sort(function(a,b) { return parseFloat(b) - parseFloat(a) }) ) {
            rows +=
`<tr id="pgVersionRow-${version}">
    <td>
        <input type="radio" name="selectedVersion" value="${version}" onclick="document.getElementById('submit').disabled = false;"></input>
        ${version}
    </td>
    <td><ul>`;
        obj.data.available_versions[version].features.forEach(function(feature) {
            rows += `<li>${feature}</li>`;
        });
    rows += `</ul></td>
    <td>
        ${new Date(obj.data.available_versions[version].release * 1000).toLocaleString(undefined, { year: 'numeric', month: 'long', day: 'numeric' })}
    </td>
    <td>
        ${new Date(obj.data.available_versions[version].EOL * 1000).toLocaleString(undefined, { year: 'numeric', month: 'long', day: 'numeric' })}
    </td>
</tr>`;
        }
        document.querySelector('#upgradeForm > table > tbody').innerHTML = rows;
    } else {
        console.log(obj.error);
    }
}

document.getElementById('submit').disabled = true;
var oReq = new XMLHttpRequest();
oReq.addEventListener("load", versionHandler);
oReq.open("GET", "api.cgi?module=Postgres&function=get_postgresql_versions");
oReq.send();
