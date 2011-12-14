#!/bin/bash
dt=linux-x86_64
./gst_dist_builder --pars sample_dist_ffgmt.xml --src_base ../gstbuilds/ffgmt/$dt/ --dst_base ./sample_dist_linux --dist_type $dt
