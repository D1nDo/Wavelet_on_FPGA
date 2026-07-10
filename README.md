# FPGA-Based Discrete Wavelet Transform (DWT) and Inverse DWT (IDWT) using Daubechies-4 Wavelets

## Overview

This repository contains a complete RTL implementation of a one-dimensional
Discrete Wavelet Transform (DWT) and Inverse Discrete Wavelet Transform (IDWT)
architecture targeting FPGA platforms.

The project implements hardware accelerators for Daubechies-4 (Db4) wavelets,
providing reusable building blocks for real-time wavelet-based processing
applications such as:

- signal denoising
- data compression
- multiresolution signal analysis
- feature extraction

The complete design is developed in Verilog RTL using Xilinx Vivado.

The objective of this repository is not to provide a final application-specific
product, but rather a collection of modular FPGA wavelet processing blocks that
can be integrated into custom DSP systems.

---

# Motivation

Wavelet transforms are widely used in digital signal processing.

Although several software implementations exist, publicly available RTL
implementations of complete wavelet processing pipelines for FPGA platforms are
limited.

This repository aims to provide reusable FPGA building blocks for researchers
and engineers developing custom hardware-based wavelet systems.

The main goals are:

- provide synthesizable RTL wavelet blocks
- implement complete DWT and IDWT architectures
- provide reusable Mallat decomposition trees
- offer a starting point for custom wavelet IP development

---

# Implemented Hardware Blocks

## 1. Db4 Wavelet Decomposition Block

The Db4 decomposition block implements the analysis stage of the DWT.

The block performs:

- low-pass filtering
- high-pass filtering
- downsampling
- generation of approximation coefficients
- generation of detail coefficients


The architecture is based on fixed-point arithmetic optimized for FPGA
implementation.

---

## 2. Db4 Wavelet Reconstruction Block

The reconstruction block implements the synthesis stage required by the IDWT.

The block performs:

- coefficient upsampling
- synthesis filtering
- signal reconstruction


When coefficients are not modified, the architecture provides perfect
reconstruction of the input signal.

---

## 3. Hard Threshold Block

A fixed hard-thresholding block is implemented for wavelet denoising and
compression.

The implemented operation is:



The threshold value is manually selected by the user.

This operation removes low-energy wavelet coefficients, which are usually
associated with noise or insignificant signal components.

---

# Block Designs

## Db4_loop

The `Db4_loop` block design implements a complete FPGA-based wavelet
compression and reconstruction pipeline using DMA data transfer.

This design is intended as a hardware demonstration of the complete DWT and IDWT
processing chain. Input samples are transferred to the FPGA through an AXI DMA
interface as 16-bit data. The samples are then processed by the Db4 wavelet
decomposition block, which separates the signal into approximation and detail
coefficients following the Mallat algorithm.

After the decomposition stage, the detail coefficients are processed by a fixed
hard threshold block. Coefficients below the selected threshold are removed,
reducing the amount of information associated with high-frequency components.

The processed coefficients are then reconstructed using the Db4 inverse wavelet
transform block.

The output data are transferred back through the DMA receive channel. The output
format is a 32-bit packed representation containing the processed detail
coefficients and approximation coefficients.

This architecture demonstrates how wavelet-based compression can be implemented
in hardware for real-time signal processing applications.

---

## Simulation

The `simulation` block design provides a complete FPGA simulation environment
for testing the wavelet denoising capability of the implemented architecture.

The input signal is generated internally using a 32-bit DDS signal generator.
A sinusoidal waveform is generated and corrupted with high-frequency noise in
order to evaluate the performance of the wavelet denoising pipeline.

The noisy signal is processed through the Db4 wavelet decomposition block. The
detail coefficients are then filtered using a fixed hard threshold operation,
removing the high-frequency components associated with noise.

Finally, the signal is reconstructed using the Db4 inverse wavelet transform.

The simulation allows direct comparison between the noisy input signal and the
reconstructed denoised signal, providing a simple demonstration of the effect
of wavelet thresholding on noise reduction.

This block design can be used as a reference environment to evaluate the
behavior of the implemented wavelet processing blocks before integration into
larger FPGA systems.

---

## all_levels_blocks

The `all_levels_blocks` block design contains reusable multilevel wavelet
processing architectures based on the Mallat decomposition tree.

Three different configurations are implemented, supporting one-level,
two-level and three-level wavelet decomposition and reconstruction.

Each configuration performs a complete wavelet denoising and compression
operation by applying Db4 decomposition, hard thresholding of detail
coefficients and Db4 reconstruction.

These architectures are designed for streaming applications, where input
samples are continuously processed without requiring complete frame storage.

Inside the Mallat trees, FIFO memories are included to compensate for the
different latencies introduced by the wavelet filter branches. Since the
approximation and detail paths have different processing delays, the FIFO blocks
are used to synchronize the coefficients before the reconstruction stage.

The resulting architectures provide real-time wavelet processing blocks that
can be directly integrated into FPGA-based signal acquisition and processing
systems.

# Build Instructions

The project can be automatically generated using the provided Vivado TCL script.

The repository contains only the required RTL sources, including the Verilog
hardware descriptions, the Vivado block designs and the project generation
script. No pre-generated Vivado project files are included in order to keep the
repository lightweight and portable.

After cloning the repository, the user can create the Vivado project by
executing the `build_project.tcl` script in batch mode or by sourcing the script
directly from the Vivado Tcl console.

The script automatically creates the project structure, imports all Verilog RTL
sources contained in the `src/hdl` folder, loads the block design files contained
in the `src/bd` folder and configures the project for synthesis and
implementation.

Once the project generation is completed, the generated Vivado project can be
opened and the desired block design can be selected according to the intended
application.

The user can then execute the standard FPGA design flow:

- synthesis
- implementation
- bitstream generation

The generated bitstream can be programmed on the target FPGA platform for
hardware evaluation.

The repository was developed and tested using Xilinx Vivado 2020.1. Different
Vivado versions may require minor modifications to the project configuration
or IP compatibility settings.

# Citation

If this repository is used in academic work, please cite:


S. Mallat,
"A Theory for Multiresolution Signal Decomposition:
The Wavelet Representation",
IEEE Transactions on Pattern Analysis and Machine Intelligence,
1989.


I. Daubechies,
"Ten Lectures on Wavelets",
SIAM,
1992.
