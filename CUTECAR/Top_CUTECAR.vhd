library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Top_CUTECAR is
  port (
    CLOCK_50 : in  std_logic;
    KEY      : in  std_logic_vector(0 downto 0);
    SW       : in  std_logic_vector(7 downto 0);
    LED      : out std_logic_vector(7 downto 0);

    --------------------------------------------------------------------
    -- SDRAM interface
    --------------------------------------------------------------------
    DRAM_CLK   : out std_logic;
    DRAM_CKE   : out std_logic;
    DRAM_ADDR  : out std_logic_vector(12 downto 0);
    DRAM_BA    : out std_logic_vector(1 downto 0);
    DRAM_CS_N  : out std_logic;
    DRAM_CAS_N : out std_logic;
    DRAM_RAS_N : out std_logic;
    DRAM_WE_N  : out std_logic;
    DRAM_DQ    : inout std_logic_vector(15 downto 0);
    DRAM_DQM   : out std_logic_vector(1 downto 0);

    --------------------------------------------------------------------
    -- Motor outputs
    --------------------------------------------------------------------
    MTRR_P : out std_logic;
    MTRR_N : out std_logic;
    MTRL_P : out std_logic;
    MTRL_N : out std_logic;

    --------------------------------------------------------------------
    -- LTC2308 ADC interface
    --------------------------------------------------------------------
    LTC_ADC_CONVST : out std_logic;
    LTC_ADC_SCK    : out std_logic;
    LTC_ADC_SDI    : out std_logic;
    LTC_ADC_SDO    : in  std_logic;

    --------------------------------------------------------------------
    -- 3.3 V power enable
    --------------------------------------------------------------------
    VCC3P3_PWRON_n : out std_logic
  );
end entity Top_CUTECAR;


architecture rtl of Top_CUTECAR is

  ----------------------------------------------------------------------
  -- Internal conduit signals
  ----------------------------------------------------------------------
  signal pwm_motor_out : std_logic_vector(3 downto 0);
  signal adc_spi_s     : std_logic_vector(2 downto 0);

  ----------------------------------------------------------------------
  -- Qsys / Platform Designer system
  ----------------------------------------------------------------------
  component Nios_CUTECAR is
    port (
      clk_clk                                                : in    std_logic;
      switches_export                                        : in    std_logic_vector(7 downto 0);
      leds_export                                            : out   std_logic_vector(7 downto 0);

      sdram_wire_addr                                        : out   std_logic_vector(12 downto 0);
      sdram_wire_ba                                          : out   std_logic_vector(1 downto 0);
      sdram_wire_cas_n                                       : out   std_logic;
      sdram_wire_cke                                         : out   std_logic;
      sdram_wire_cs_n                                        : out   std_logic;
      sdram_wire_dq                                          : inout std_logic_vector(15 downto 0);
      sdram_wire_dqm                                         : out   std_logic_vector(1 downto 0);
      sdram_wire_ras_n                                       : out   std_logic;
      sdram_wire_we_n                                        : out   std_logic;

      reset_reset_n                                          : in    std_logic;
      clocks_sdram_clk_clk                                   : out   std_logic;

      pwm_generation_avalon_interface_0_conduit_end_export   : out   std_logic_vector(3 downto 0);

      capteurs_sol_seuil_avalon_0_conduit_end_adc_spi_export : out   std_logic_vector(2 downto 0);
      capteurs_sol_seuil_avalon_0_conduit_end_adc_sdo_export : in    std_logic
    );
  end component Nios_CUTECAR;

begin

  ----------------------------------------------------------------------
  -- Qsys instance
  ----------------------------------------------------------------------
  u0 : Nios_CUTECAR
    port map (
      ------------------------------------------------------------------
      -- Clock and reset
      ------------------------------------------------------------------
      clk_clk       => CLOCK_50,
      reset_reset_n => KEY(0),

      ------------------------------------------------------------------
      -- Switches and LEDs
      ------------------------------------------------------------------
      switches_export => SW,
      leds_export     => LED,

      ------------------------------------------------------------------
      -- SDRAM physical interface
      ------------------------------------------------------------------
      sdram_wire_addr  => DRAM_ADDR,
      sdram_wire_ba    => DRAM_BA,
      sdram_wire_cas_n => DRAM_CAS_N,
      sdram_wire_cke   => DRAM_CKE,
      sdram_wire_cs_n  => DRAM_CS_N,
      sdram_wire_dq    => DRAM_DQ,
      sdram_wire_dqm   => DRAM_DQM,
      sdram_wire_ras_n => DRAM_RAS_N,
      sdram_wire_we_n  => DRAM_WE_N,

      ------------------------------------------------------------------
      -- SDRAM clock generated by Qsys
      ------------------------------------------------------------------
      clocks_sdram_clk_clk => DRAM_CLK,

      ------------------------------------------------------------------
      -- PWM motor conduit
      ------------------------------------------------------------------
      pwm_generation_avalon_interface_0_conduit_end_export => pwm_motor_out,

      ------------------------------------------------------------------
      -- ADC conduit
      ------------------------------------------------------------------
      capteurs_sol_seuil_avalon_0_conduit_end_adc_spi_export => adc_spi_s,
      capteurs_sol_seuil_avalon_0_conduit_end_adc_sdo_export => LTC_ADC_SDO
    );

  ----------------------------------------------------------------------
  -- PWM conduit mapping
  ----------------------------------------------------------------------
  -- pwm_motor_out(3) = right motor positive
  -- pwm_motor_out(2) = right motor negative
  -- pwm_motor_out(1) = left motor positive
  -- pwm_motor_out(0) = left motor negative
  ----------------------------------------------------------------------
  MTRR_P <= pwm_motor_out(3);
  MTRR_N <= pwm_motor_out(2);
  MTRL_P <= pwm_motor_out(1);
  MTRL_N <= pwm_motor_out(0);

  ----------------------------------------------------------------------
  -- ADC SPI conduit mapping
  ----------------------------------------------------------------------
  -- adc_spi_s(2) = ADC_CONVST
  -- adc_spi_s(1) = ADC_SCK
  -- adc_spi_s(0) = ADC_SDI
  ----------------------------------------------------------------------
  LTC_ADC_CONVST <= adc_spi_s(2);
  LTC_ADC_SCK    <= adc_spi_s(1);
  LTC_ADC_SDI    <= adc_spi_s(0);

  ----------------------------------------------------------------------
  -- Enable 3.3 V power
  ----------------------------------------------------------------------
  VCC3P3_PWRON_n <= '0';

end architecture rtl;