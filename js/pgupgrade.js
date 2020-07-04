function doAPIRequestWithCallback (meth, mod, func, handler, errorHandler, args) {
    'use strict';
    let oReq = new XMLHttpRequest();
    oReq.onreadystatechange = function() {
        if (this.readyState === XMLHttpRequest.DONE) {
            if( this.status === 200 ) {
                handler(this.responseText);
            } else {
                errorHandler(meth, mod, func, this.status, this.responseText);
            }
        }
    }
    let argarr = [ `module=${mod}`, `function=${func}` ];
    if( typeof args === 'object' ) {
        Object.keys(args).forEach( function(argument) {
            argarr.push(`${argument}=${args[argument]}`);
        });
    }
    let argstr = argarr.join("&");

    if( meth === 'GET' ) {
        oReq.open( meth, `api.cgi?${argstr}`, true );
        oReq.send();
    } else if ( meth === 'POST' ) {
        oReq.open( meth, "api.cgi", true );
        oReq.setRequestHeader( "Content-type", "application/x-www-form-urlencoded" );
        console.log(argstr);
        oReq.send(argstr);
    }
    return false;
}

function generalErrorHandler(meth, mod, func, code, txt) {
    console.log(txt);
    alert(`${meth} call to Troglodyne::API::${mod}::${func} failed with error code ${code}! Please see the JS console for details.`);
    return false;
}

function safeParseJSON(txt) {
    let obj = {};
    try {
        obj = JSON.parse(txt);
    } catch(e) {
        console.log(txt);
        return { "error": e };
    }
    return obj;
}

function versionHandler (resp) {
    'use strict';
    let obj = safeParseJSON(resp);
    if(obj.result === 1) {

        // Construct version warning/display
        let pgVersion = obj.data.installed_version.major + '.' + obj.data.installed_version.minor;
        let elem = document.getElementById('psqlVersion');
        let html = `<strong>${pgVersion}</strong>`;
        if( parseFloat(pgVersion) < parseFloat(obj.data.minimum_supported_version) ) {
            elem.classList.add('callout', 'callout-danger');
            html += ' -- You are using a version of PostgreSQL Server that is no longer supported by ';
            html += '<a href="https://www.postgresql.org/support/versioning/" title="PostgreSQL Supported versions page">postgresql.org</a>!<br>';
            if( obj.data.eol_versions.hasOwnProperty(pgVersion) ) {
                html += "<strong>EOL</strong> -- " + new Date(obj.data.eol_versions[pgVersion].EOL * 1000).toLocaleString( undefined, { year: 'numeric', month: 'long', day: 'numeric' } ) + "<br>";
            }
            html += "<strong>Immediate upgrade is recommended.</strong>";
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

function doInstallScroller (resp) {
    'use strict';
    let obj = safeParseJSON(resp);
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
        doAPIRequestWithCallback( 'POST', 'Postgres', 'start_postgres_install', handlePGInstall, generalErrorHandler, { "version": window.selectedVersion } );
    } else {
         console.log(obj.error);
         upgradeWell.textContent += "Installlation of community repositories failed:" + obj.error;
         submitBtn.textContent = 'Re-Try';
         submitBtn.disabled = false;
    }
    return false;
}

function handlePGInstall (resp) {
    'use strict';
    let obj = safeParseJSON(resp);
    console.log(resp);
    let upgradeWell = document.getElementById('upgradeWell');
    let submitBtn = document.getElementById('submit');
    if(obj.result === 1) {
        console.log(obj);
        upgradeWell.textContent += `Attaching to log file ${obj.data.log} from process #${obj.data.pid}...\n\n`;
        doAPIRequestWithCallback( 'GET', 'Postgres', 'get_latest_upgradelog_messages', roadRoller, generalErrorHandler, { "pid": obj.data.pid, "log": obj.data.log, "start": 0 } );
    } else {
         upgradeWell.textContent += `Installlation PostgreSQL ${window.selectedVersion} failed: ${obj.error}`;
         submitBtn.textContent = 'Re-Try';
         submitBtn.disabled = false;
    }

    return false;
}

// 8 seconds have passed
function roadRoller (resp) {
    'use strict';
    let obj = safeParseJSON(resp);
    let upgradeWell = document.getElementById('upgradeWell');
    let submitBtn = document.getElementById('submit');
    if(obj.result === 1) {

        // Paste in new content
        upgradeWell.textContent += obj.data['new_content'];
        upgradeWell.scrollTo(0,upgradeWell.scrollHeight);
        if(obj.data['in_progress']) {
            // Not done yet, keep going
            doAPIRequestWithCallback(
                'GET', 'Postgres', 'get_latest_upgradelog_messages', roadRoller, generalErrorHandler, {
                    "pid": obj.metadata['input_args'].pid,
                    "log": obj.metadata['input_args'].log,
                    "start": obj.data['next']
                }
            );
        } else {
            // Do something based on the end status
            if(+obj.data['child_exit']) {
                 upgradeWell.textContent += `Installation of PostgreSQL ${window.selectedVersion} failed: Subprocess exited ${obj.data['child_exit']}`;
                 submitBtn.textContent = 'Re-Try';
                 submitBtn.disabled = false;
                 return;
            }
            upgradeWell.textContent += `Installation of PostgreSQL ${window.selectedVersion} completed successfully!`;
            upgradeWell.scrollTo(0,upgradeWell.scrollHeight);
            submitBtn.textContent = 'All done, please refresh the page.';
        }
    } else {
         upgradeWell.textContent += `Installation of PostgreSQL ${window.selectedVersion} failed: ${obj.error}`;
         upgradeWell.scrollTo(0,upgradeWell.scrollHeight);
         submitBtn.textContent = 'Re-Try';
         submitBtn.disabled = false;
    }
}

window.doUpgrade = function () {
    'use strict';
    let form = new FormData(upgradeForm);
    window.selectedVersion = form.get('selectedVersion');
    document.getElementById('upgradeTitle').textContent = "Install Progress for PostgreSQL " + window.selectedVersion;
    let submitBtn = document.getElementById('submit');
    submitBtn.disabled = true;
    submitBtn.innerHTML = '<span class="fa fa-spin fa-spinner"></span>';
    let upgradeWell = document.getElementById('upgradeWell');
    upgradeWell.textContent = 'Ensuring that the PostgreSQL Community repository is installed...\n';
    upgradeWell.style.display = "block";
    upgradeForm.style.display = "none";
    doAPIRequestWithCallback( 'GET', 'Postgres', 'enable_community_repositories', doInstallScroller, generalErrorHandler );

    return false;
}

// Now kickoff the page load post bits
document.getElementById('submit').disabled = true;
doAPIRequestWithCallback( 'GET', 'Postgres', 'get_postgresql_versions', versionHandler, generalErrorHandler );
