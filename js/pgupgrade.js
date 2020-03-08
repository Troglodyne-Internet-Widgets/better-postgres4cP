function doAPIRequestWithCallback (mod, func, handler) {
    'use strict';
    var oReq = new XMLHttpRequest();
    oReq.addEventListener("load", handler);
    oReq.open("GET", `api.cgi?module=${mod}&function=${func}`);
    oReq.send();
    return false;
}

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
        document.getElementById('loadingCell').remove();
        document.querySelector('#upgradeForm > table > tbody').innerHTML = rows;
    } else {
        console.log(obj.error);
    }
}

function doInstallScroller () {
    'use strict';
    let obj = JSON.parse(this.responseText);
    let upgradeWell = document.getElementById('upgradeWell');
    let submitBtn = document.getElementById('submit');
    if(obj.result === 1) {
        if(obj.data.exit_code !== 0) {
            upgradeWell.textContent += obj.data.last_yum_command + " reported nonzero exit code (" + obj.data.exit_code + "):\n[STDOUT] " + obj.data.stdout + "\n[STDERR] " + obj.data.stderr;
            submitBtn.textContent = 'Re-Try';
            submitBtn.disabled = false;
            return false;
        }
        if(obj.data.already_installed) {
            upgradeWell.textContent += obj.data.last_yum_command + " reports the community repository is already installed: " + obj.data.stdout;
        } else {
            upgradeWell.textContent += obj.data.last_yum_command + "\n" + obj.data.stdout;
        }
        // Ok, now kick off actual install TODO use WebSocket?
        upgradeWell.textContent += "\nNow proceeding with install of PostgreSQL " + window.selectedVersion + "...\n";
    } else {
         upgradeWell.textContent += "Installlation of community repositories failed:" + obj.reason;
         submitBtn.textContent = 'Re-Try';
         submitBtn.disabled = false;
    }
    return false;
}

window.doUpgrade = function (form) {
    'use strict';
    window.selectedVersion = form.get('selectedVersion');
    document.getElementById('upgradeTitle').textContent = "Install Progress for PostgreSQL " + window.selectedVersion;
    let submitBtn = document.getElementById('submit');
    submitBtn.disabled = true;
    submitBtn.innerHTML = '<span class="fa fa-spin fa-spinner"></span>';
    document.getElementById('upgradeDiv').innerHTML = '<pre id="upgradeWell" class="well">Ensuring that the PostgreSQL Community repository is installed...\n</pre>';
    doAPIRequestWithCallback('Postgres', 'enable_community_repositories', doInstallScroller );
    return false;
}

// Now kickoff the page load post bits
document.getElementById('submit').disabled = true;
doAPIRequestWithCallback('Postgres', 'get_postgresql_versions', versionHandler);
