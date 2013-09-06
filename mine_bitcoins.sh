#!/bin/bash

# put anything custom mining env setup here

cd ~/cgminer
sudo ./cgminer-nogpu -o stratum+tcp://stratum.bitcoin.cz:3333 -O januszeal.asic0:dongs -G
