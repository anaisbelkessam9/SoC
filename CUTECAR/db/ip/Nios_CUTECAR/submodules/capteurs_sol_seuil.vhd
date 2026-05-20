--------------------------------------------------------------------------------
-- Module d'acquisition capteurs de sol via ADC LTC2308
-- Interface SPI - Fréquence max 40 MHz
-- Lecture de 7 canaux analogiques avec seuillage configurable
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity capteurs_sol_seuil is
    port (
        -- Horloge et reset système
        clk       : in  std_logic;  -- Max 40 MHz
        reset_n   : in  std_logic;
        
        -- Interface de contrôle
        data_capture : in  std_logic;   -- Déclenchement acquisition (front montant)
        data_readyr  : out std_logic;   -- Données disponibles
        
        -- Sorties des 7 capteurs (8 bits chacun)
        data0r : out std_logic_vector(7 downto 0);
        data1r : out std_logic_vector(7 downto 0);
        data2r : out std_logic_vector(7 downto 0);
        data3r : out std_logic_vector(7 downto 0);
        data4r : out std_logic_vector(7 downto 0);
        data5r : out std_logic_vector(7 downto 0);
        data6r : out std_logic_vector(7 downto 0);
        
        -- Configuration seuillage
        NIVEAU    : in  std_logic_vector(7 downto 0);
        vect_capt : out std_logic_vector(6 downto 0);  -- Vecteur binaire seuillé
        
        -- Interface SPI vers ADC
        ADC_CONVSTr : out std_logic;  -- Start conversion
        ADC_SCK     : out std_logic;  -- Clock SPI
        ADC_SDIr    : out std_logic;  -- Data out (FPGA → ADC)
        ADC_SDO     : in  std_logic   -- Data in (ADC → FPGA)
    );
end entity capteurs_sol_seuil;

architecture RTL of capteurs_sol_seuil is

    ------------------------------------------------------------------------
    -- Constantes de timing
    ------------------------------------------------------------------------
    constant CLOCK_DUR            : integer := 25;   -- Période horloge = 25 ns (40 MHz)
    constant CONVST_WAIT_CLOCK_NUM : integer := ((1600 + CLOCK_DUR - 1) / CLOCK_DUR);  -- ~1.6 µs

    ------------------------------------------------------------------------
    -- Machine à états pour l'acquisition SPI
    ------------------------------------------------------------------------
    type State_type is (S0, S1, S2, S3, S4, S5, S6, S7);
    signal State : State_Type;

    ------------------------------------------------------------------------
    -- Signaux internes de données (12 bits bruts de l'ADC)
    ------------------------------------------------------------------------
    signal data_ready : std_logic;
    signal data0 : std_logic_vector(11 downto 0);
    signal data1 : std_logic_vector(11 downto 0);
    signal data2 : std_logic_vector(11 downto 0);
    signal data3 : std_logic_vector(11 downto 0);
    signal data4 : std_logic_vector(11 downto 0);
    signal data5 : std_logic_vector(11 downto 0);
    signal data6 : std_logic_vector(11 downto 0);
    signal data7 : std_logic_vector(11 downto 0);
    
    -- Vecteur compact de toutes les données
    signal vect_data : std_logic_vector(55 downto 0);
    
    ------------------------------------------------------------------------
    -- Signaux SPI
    ------------------------------------------------------------------------
    signal ADC_CONVST : std_logic;
    signal ADC_SDI    : std_logic;
    signal ADC_SCKl   : std_logic;

    ------------------------------------------------------------------------
    -- Signaux de contrôle
    ------------------------------------------------------------------------
    signal pre_data_capture     : std_logic;
    signal data_capture_trigger : std_logic;
    
    signal wait_tick_cnt   : unsigned(7 downto 0);  -- Compteur d'attente conversion
    signal last_data_bits  : std_logic;
    signal data_bit_index  : std_logic_vector(3 downto 0);  -- Index du bit en cours
    
    signal last_channel : std_logic;
    signal channel      : std_logic_vector(3 downto 0);  -- Canal ADC actuel
    
    signal spi_clk_enable : std_logic;  -- Enable horloge SPI
    
    signal channel_config      : std_logic_vector(5 downto 0);  -- Config canal ADC
    signal sdi_data_bit_index  : std_logic_vector(3 downto 0);
    signal rx_data_bit_index   : std_logic_vector(3 downto 0);

begin

    ------------------------------------------------------------------------
    -- Connexions des sorties
    ------------------------------------------------------------------------
    data_readyr  <= data_ready;
    ADC_CONVSTr  <= ADC_CONVST;
    ADC_SDIr     <= ADC_SDI;

    ------------------------------------------------------------------------
    -- PROCESS : Machine à états principale
    ------------------------------------------------------------------------
    fsm_proc : process(clk, reset_n)
        variable ii : integer;
    begin
        if (reset_n /= '1') then
            State          <= S0;
            data_bit_index <= (others => '0');
            wait_tick_cnt  <= to_unsigned(0, 8);
            ADC_SDI        <= '0';
            ADC_CONVST     <= '0';
            spi_clk_enable <= '0';
            
        elsif rising_edge(clk) then
            case State is
                
                -- État 0 : Idle, attente du trigger
                when S0 =>
                    channel    <= (others => '0');
                    data_ready <= '0';
                    if (data_capture = '1') then
                        State      <= S1;
                        ADC_CONVST <= '1';
                    end if;
                
                -- État 1 : Initialisation conversion
                when S1 =>
                    wait_tick_cnt <= to_unsigned(0, 8);
                    ADC_CONVST    <= '1';
                    State         <= S2;
                
                -- État 2 : Attente fin de conversion (~1.6 µs)
                when S2 =>
                    spi_clk_enable <= '0';
                    ADC_CONVST     <= '0';
                    ADC_SDI        <= '0';
                    wait_tick_cnt  <= wait_tick_cnt + 1;
                    data_bit_index <= (others => '0');
                    
                    if (wait_tick_cnt >= to_unsigned(CONVST_WAIT_CLOCK_NUM, 8)) then
                        State <= S3;
                    end if;
                
                -- État 3 : Acquisition des 12 bits SPI
                when S3 =>
                    spi_clk_enable <= '1';
                    
                    -- Envoi de la configuration du canal (6 premiers bits)
                    if (unsigned(data_bit_index) < 6) then
                        ii      := to_integer(5 - unsigned(data_bit_index));
                        ADC_SDI <= channel_config(ii);
                    else
                        ADC_SDI <= '0';
                    end if;
                    
                    data_bit_index <= std_logic_vector(unsigned(data_bit_index) + 1);
                    
                    -- Fin de l'acquisition (12 bits reçus)
                    if (unsigned(data_bit_index) >= 11) then
                        State <= S4;
                    end if;
                
                -- État 4 : Passage au canal suivant
                when S4 =>
                    spi_clk_enable <= '0';
                    channel        <= std_logic_vector(unsigned(channel) + 1);
                    
                    -- Dernier canal (8 canaux, mais on n'utilise que 7)
                    if (channel = "1000") then
                        State      <= S5;
                        data_ready <= '1';
                        
                        -- Extraction des 8 bits de poids fort
                        data0r <= data0(11 downto 4);
                        data1r <= data1(11 downto 4);
                        data2r <= data2(11 downto 4);
                        data3r <= data3(11 downto 4);
                        data4r <= data4(11 downto 4);
                        data5r <= data5(11 downto 4);
                        data6r <= data6(11 downto 4);
                    else
                        State      <= S1;
                        ADC_CONVST <= '1';
                    end if;
                
                -- État 5 : Données prêtes, attente relâchement trigger
                when S5 =>
                    if (data_capture = '0') then
                        State <= S0;
                    end if;
                
                when others =>
                    null;
                    
            end case;
        end if;
    end process fsm_proc;

    ------------------------------------------------------------------------
    -- Génération horloge SPI (inversée par rapport à clk système)
    ------------------------------------------------------------------------
    ADC_SCKl <= not clk when (spi_clk_enable = '1') else '0';

    ------------------------------------------------------------------------
    -- PROCESS : Configuration des canaux ADC
    ------------------------------------------------------------------------
    channel_config_proc : process(channel)
    begin
        case channel is
            when "1000" => channel_config <= "100010";  -- CH0
            when "0000" => channel_config <= "100010";  -- CH0
            when "0001" => channel_config <= "110010";  -- CH1
            when "0010" => channel_config <= "100110";  -- CH2
            when "0011" => channel_config <= "110110";  -- CH3
            when "0100" => channel_config <= "101010";  -- CH4
            when "0101" => channel_config <= "111010";  -- CH5
            when "0110" => channel_config <= "101110";  -- CH6
            when "0111" => channel_config <= "111110";  -- CH7
            when others => null;
        end case;
    end process channel_config_proc;

    ------------------------------------------------------------------------
    -- Index de réception des données
    ------------------------------------------------------------------------
    rx_data_bit_index <= std_logic_vector(12 - unsigned(data_bit_index));

    ------------------------------------------------------------------------
    -- Connexion horloge SPI
    ------------------------------------------------------------------------
    ADC_SCK <= ADC_SCKl;

    ------------------------------------------------------------------------
    -- PROCESS : Réception des données SPI sur front montant
    ------------------------------------------------------------------------
    spi_receive_proc : process(ADC_SCKl)
    begin
        if rising_edge(ADC_SCKl) then
            case channel is
                when "0001" => data0 <= data0(10 downto 0) & ADC_SDO;
                when "0010" => data1 <= data1(10 downto 0) & ADC_SDO;
                when "0011" => data2 <= data2(10 downto 0) & ADC_SDO;
                when "0100" => data3 <= data3(10 downto 0) & ADC_SDO;
                when "0101" => data4 <= data4(10 downto 0) & ADC_SDO;
                when "0110" => data5 <= data5(10 downto 0) & ADC_SDO;
                when "0111" => data6 <= data6(10 downto 0) & ADC_SDO;
                when "1000" => data7 <= data7(10 downto 0) & ADC_SDO;
                when others => null;
            end case;
        end if;
    end process spi_receive_proc;

    ------------------------------------------------------------------------
    -- Construction du vecteur compact de données (7 capteurs × 8 bits)
    ------------------------------------------------------------------------
    vect_data <= data6(11 downto 4) & data5(11 downto 4) &
                 data4(11 downto 4) & data3(11 downto 4) &
                 data2(11 downto 4) & data1(11 downto 4) & data0(11 downto 4);

    ------------------------------------------------------------------------
    -- Seuillage : comparaison de chaque capteur avec NIVEAU
    ------------------------------------------------------------------------
    threshold_gen : for i in 0 to 6 generate
        vect_capt(i) <= '1' when (unsigned(vect_data(7 + i*8 downto i*8)) > unsigned(NIVEAU)) else '0';
    end generate threshold_gen;

end architecture RTL;