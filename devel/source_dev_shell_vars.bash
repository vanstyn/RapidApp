# ------------------------------------------------------------------
# 'source' this script to update ENV vars to make the RapidApp repo
# this file is contained in active for your shell for development.
#
# This will update the following environment variables, preserving
# existing values (i.e. appending vs replacing) appropriately
#
#  * PERLLIB
#  * PATH
#  * RAPIDAPP_SHARE_DIR
#
# #166 (https://github.com/vanstyn/RapidApp/issues/166)
# ------------------------------------------------------------------

if [ $0 == ${BASH_SOURCE[0]} ]; then
  echo "Oops! This script needs to be 'sourced' to work -- like this:";
  echo -e "\n  source $0\n";
  exit 1;
fi;

do_source_vars() {
  local dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  local prl="print_dev_exports.pl"
  
  if [ -e "$dir/$prl" ]; then
    local export_cmds;
    export_cmds=`perl $dir/$prl`;
    local exit=$?;
    if [ $exit -ne 0 ]; then
      echo "An error occured calling $dir/$prl (exit: $exit)";
    else
      eval $export_cmds;
      exit=$?;
      if [ $exit -ne 0 ]; then
        echo "An unknown error occured attempting to export shell variables";
      else
        echo " -- Exported RapidApp env variables to your shell: --";
        echo -e "\n$export_cmds\n";
      fi;
    fi;
  else
    echo "Error! $prl script not found! Did you move this script?";
    # note: we're not calling exit here because we've been sourced 
    # and this would cause the parent shell to exit
  fi;
}

do_source_vars;
