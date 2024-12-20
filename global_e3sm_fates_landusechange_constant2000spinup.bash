#!/usr/bin/env bash

SRCDIR=$HOME/E3SM/components/elm/src/
cd ${SRCDIR}
GITHASH1=`git log -n 1 --format=%h`
cd external_models/fates
GITHASH2=`git log -n 1 --format=%h`

SETUP_CASE=fates_4x5_nocomp_0008_frombareground_const2000lu_2pctgrazing
    
CASE_NAME=${SETUP_CASE}_${GITHASH1}_${GITHASH2}
basedir=$HOME/E3SM/cime/scripts

cd $basedir
export RES=f45_f45
project=m2467

./create_newcase -case ${CASE_NAME} -res ${RES} -compset IELMFATES -mach pm-cpu -project $project


cd $CASE_NAME

ncgen -o fates_params_default_${GITHASH2}.nc ${SRCDIR}/external_models/fates/parameter_files/fates_params_default.cdl

# add more age bins to history output
/global/homes/c/cdkoven/E3SM/components/elm/src/external_models/fates/tools/modify_fates_paramfile.py --fin=fates_params_default_${GITHASH2}.nc --fout=fates_params_default_${GITHASH2}.nc --O --var=fates_history_ageclass_bin_edges --val=0,1,2,5,10,20,50,100,200 --changeshape

# make the seed rain amount nonzero for grasses (c4 and cool c3 only)
#/global/homes/c/cdkoven/E3SM/components/elm/src/external_models/fates/tools/modify_fates_paramfile.py --fin=fates_params_default_${GITHASH2}.nc --fout=fates_params_default_${GITHASH2}_mod.nc --pft 12 --var fates_recruit_seed_supplement --val 1e-3
#/global/homes/c/cdkoven/E3SM/components/elm/src/external_models/fates/tools/modify_fates_paramfile.py --fin=fates_params_default_${GITHASH2}_mod.nc --fout=fates_params_default_${GITHASH2}_mod.nc --pft 11 --var fates_recruit_seed_supplement --val 1e-3 --O

# make grazing happen at 4%/day
/global/homes/c/cdkoven/E3SM/components/elm/src/external_models/fates/tools/modify_fates_paramfile.py --fin=fates_params_default_${GITHASH2}.nc --fout=fates_params_default_${GITHASH2}.nc --O --var=fates_landuse_grazing_rate --val=0,0,0.02,0.02,0

# debugging phase
# ./xmlchange DEBUG=TRUE
# ./xmlchange STOP_N=6
# ./xmlchange STOP_OPTION=nmonths
# ./xmlchange JOB_QUEUE=debug

# fates_harvest_mode = 'no_harvest'
# fates_harvest_mode = 'luhdata_area'


./xmlchange RUN_STARTDATE=0001-01-01
./xmlchange RESUBMIT=0
./xmlchange -id ELM_BLDNML_OPTS -val "-bgc fates -no-megan -no-drydep"
./xmlchange NTASKS=-5
./xmlchange STOP_N=15
./xmlchange REST_N=5
./xmlchange STOP_OPTION=nyears
./xmlchange JOB_QUEUE=regular
./xmlchange JOB_WALLCLOCK_TIME=06:00:00
./xmlchange CCSM_CO2_PPMV=370.
    

cat > user_nl_elm <<EOF
flandusepftdat = '/global/homes/c/cdkoven/scratch/inputdata/fates_landuse_pft_map_4x5_20240206.nc'
use_fates_luh = .true.
use_fates_nocomp = .true.
use_fates_fixed_biogeog = .true.
fates_paramfile = '${basedir}/${CASE_NAME}/fates_params_default_${GITHASH2}.nc'
use_fates_sp = .false.
fates_spitfire_mode = 1
fates_harvest_mode = 'luhdata_area'
use_fates_potentialveg = .false.
fluh_timeseries = '/global/homes/c/cdkoven/scratch/inputdata/LUH2_states_transitions_management.timeseries_4x5_hist_steadystate_2000_2024-10-30.nc'
use_century_decomp = .true.
spinup_state = 0
suplphos = 'ALL'
suplnitro = 'ALL'
hist_fincl1 = 'FATES_SECONDARY_ANTHRODISTAGE_AP','FATES_SECONDARY_AREA_AP','FATES_PRIMARY_AREA_AP','FATES_NPP_LU','FATES_GPP_LU'  
EOF



./case.setup
./case.build
./case.submit
