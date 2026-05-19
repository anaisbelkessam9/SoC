--------------------------------------------------------------------------------
-- Capteur Sol Core - Acquisition SPI des capteurs de sol
-- Lit 7 capteurs via ADC SPI, applique un seuillage
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY capteur_sol_core IS
    PORT (
        -- Système
        clock           : IN  STD_LOGIC;
        resetn          : IN  STD_LOGIC;
        
        -- Contrôle
        trigger         : IN  STD_LOGIC;  -- Front montant pour lancer acquisition
        data_ready      : OUT STD_LOGIC;  -- '1' quand données disponibles
        
        -- Configuration
        seuil           : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
        
        -- Données brutes des capteurs (8 bits chacun)
        data0           : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        data1           : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        data2           : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        data3           : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        data4           : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        data5           : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        data6           : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        
        -- Vecteur binaire seuillé
        vect_capt       : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        
        -- Interface SPI vers ADC
        ADC_CONVST      : OUT STD_LOGIC;
        ADC_SCK         : OUT STD_LOGIC;
        ADC_SDI         : OUT STD_LOGIC;
        ADC_SDO         : IN  STD_LOGIC
    );
END capteur_sol_core;

ARCHITECTURE Behavior OF capteur_sol_core IS
    
    -- Constantes timing (@ 50 MHz)
    CONSTANT CONVST_WAIT : INTEGER := 64;  -- ~1.6µs
    
    -- Machine d'états
    TYPE state_type IS (S_IDLE, S_CONV, S_WAIT, S_ACQUIRE, S_DONE);
    SIGNAL state : state_type;
    
    -- Compteurs
    SIGNAL wait_cnt : UNSIGNED(7 DOWNTO 0);
    SIGNAL bit_index : UNSIGNED(3 DOWNTO 0);
    SIGNAL channel : UNSIGNED(2 DOWNTO 0);
    
    -- Registres de données (12 bits bruts de l'ADC)
    TYPE data_array IS ARRAY (0 TO 6) OF STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL data_reg : data_array;
    
    -- Signaux SPI
    SIGNAL spi_clk_enable : STD_LOGIC;
    SIGNAL channel_config : STD_LOGIC_VECTOR(5 DOWNTO 0);
    
    -- Détection front montant trigger
    SIGNAL trigger_prev : STD_LOGIC;
    SIGNAL trigger_edge : STD_LOGIC;
    
BEGIN
    
    ------------------------------------------------------------------------
    -- Détection du front montant sur trigger
    ------------------------------------------------------------------------
    PROCESS(clock, resetn)
    BEGIN
        IF resetn = '0' THEN
            trigger_prev <= '0';
            trigger_edge <= '0';
        ELSIF rising_edge(clock) THEN
            trigger_prev <= trigger;
            trigger_edge <= trigger AND NOT trigger_prev;
        END IF;
    END PROCESS;
    
    ------------------------------------------------------------------------
    -- Machine d'états principale (acquisition SPI)
    ------------------------------------------------------------------------
    PROCESS(clock, resetn)
    BEGIN
        IF resetn = '0' THEN
            state <= S_IDLE;
            data_ready <= '0';
            ADC_CONVST <= '0';
            ADC_SDI <= '0';
            spi_clk_enable <= '0';
            wait_cnt <= (OTHERS => '0');
            bit_index <= (OTHERS => '0');
            channel <= (OTHERS => '0');
            
        ELSIF rising_edge(clock) THEN
            CASE state IS
                
                -- IDLE : Attente du trigger
                WHEN S_IDLE =>
                    data_ready <= '0';
                    spi_clk_enable <= '0';
                    IF trigger_edge = '1' THEN
                        state <= S_CONV;
                        channel <= (OTHERS => '0');
                        ADC_CONVST <= '1';
                    END IF;
                
                -- CONV : Début conversion ADC
                WHEN S_CONV =>
                    ADC_CONVST <= '1';
                    wait_cnt <= (OTHERS => '0');
                    state <= S_WAIT;
                
                -- WAIT : Attente fin conversion (~1.6µs)
                WHEN S_WAIT =>
                    ADC_CONVST <= '0';
                    ADC_SDI <= '0';
                    spi_clk_enable <= '0';
                    wait_cnt <= wait_cnt + 1;
                    bit_index <= (OTHERS => '0');
                    
                    IF wait_cnt >= CONVST_WAIT THEN
                        state <= S_ACQUIRE;
                    END IF;
                
                -- ACQUIRE : Acquisition des 12 bits via SPI
                WHEN S_ACQUIRE =>
                    spi_clk_enable <= '1';
                    
                    -- Configuration canal (6 premiers bits)
                    IF bit_index < 6 THEN
                        ADC_SDI <= channel_config(5 - to_integer(bit_index));
                    ELSE
                        ADC_SDI <= '0';
                    END IF;
                    
                    bit_index <= bit_index + 1;
                    
                    -- Fin acquisition (12 bits)
                    IF bit_index >= 11 THEN
                        spi_clk_enable <= '0';
                        channel <= channel + 1;
                        
                        -- Dernier canal (7 capteurs)
                        IF channel = 6 THEN
                            state <= S_DONE;
                            data_ready <= '1';
                        ELSE
                            state <= S_CONV;
                            ADC_CONVST <= '1';
                        END IF;
                    END IF;
                
                -- DONE : Données prêtes, attente trigger='0'
                WHEN S_DONE =>
                    data_ready <= '1';
                    spi_clk_enable <= '0';
                    IF trigger = '0' THEN
                        state <= S_IDLE;
                        data_ready <= '0';
                    END IF;
                
            END CASE;
        END IF;
    END PROCESS;
    
    ------------------------------------------------------------------------
    -- Configuration des canaux ADC (unipolar, not sleep)
    ------------------------------------------------------------------------
    PROCESS(channel)
    BEGIN
        CASE channel IS
            WHEN "000" => channel_config <= "100010";  -- CH0
            WHEN "001" => channel_config <= "110010";  -- CH1
            WHEN "010" => channel_config <= "100110";  -- CH2
            WHEN "011" => channel_config <= "110110";  -- CH3
            WHEN "100" => channel_config <= "101010";  -- CH4
            WHEN "101" => channel_config <= "111010";  -- CH5
            WHEN "110" => channel_config <= "101110";  -- CH6
            WHEN OTHERS => channel_config <= "100010";
        END CASE;
    END PROCESS;
    
    ------------------------------------------------------------------------
    -- Génération horloge SPI (clock inversée)
    ------------------------------------------------------------------------
    ADC_SCK <= NOT clock WHEN spi_clk_enable = '1' ELSE '0';
    
    ------------------------------------------------------------------------
    -- Réception des données sur front montant de clock
    ------------------------------------------------------------------------
    PROCESS(clock)
    BEGIN
        IF rising_edge(clock) THEN
            IF spi_clk_enable = '1' AND bit_index > 0 THEN
                -- Shift register pour chaque canal
                data_reg(to_integer(channel)) <= 
                    data_reg(to_integer(channel))(10 DOWNTO 0) & ADC_SDO;
            END IF;
        END IF;
    END PROCESS;
    
    ------------------------------------------------------------------------
    -- Extraction des 8 bits de poids fort (sur 12 bits ADC)
    ------------------------------------------------------------------------
    data0 <= data_reg(0)(11 DOWNTO 4);
    data1 <= data_reg(1)(11 DOWNTO 4);
    data2 <= data_reg(2)(11 DOWNTO 4);
    data3 <= data_reg(3)(11 DOWNTO 4);
    data4 <= data_reg(4)(11 DOWNTO 4);
    data5 <= data_reg(5)(11 DOWNTO 4);
    data6 <= data_reg(6)(11 DOWNTO 4);
    
    ------------------------------------------------------------------------
    -- Seuillage : comparaison avec le seuil configurable
    ------------------------------------------------------------------------
    vect_capt(0) <= '1' WHEN UNSIGNED(data_reg(0)(11 DOWNTO 4)) > UNSIGNED(seuil) ELSE '0';
    vect_capt(1) <= '1' WHEN UNSIGNED(data_reg(1)(11 DOWNTO 4)) > UNSIGNED(seuil) ELSE '0';
    vect_capt(2) <= '1' WHEN UNSIGNED(data_reg(2)(11 DOWNTO 4)) > UNSIGNED(seuil) ELSE '0';
    vect_capt(3) <= '1' WHEN UNSIGNED(data_reg(3)(11 DOWNTO 4)) > UNSIGNED(seuil) ELSE '0';
    vect_capt(4) <= '1' WHEN UNSIGNED(data_reg(4)(11 DOWNTO 4)) > UNSIGNED(seuil) ELSE '0';
    vect_capt(5) <= '1' WHEN UNSIGNED(data_reg(5)(11 DOWNTO 4)) > UNSIGNED(seuil) ELSE '0';
    vect_capt(6) <= '1' WHEN UNSIGNED(data_reg(6)(11 DOWNTO 4)) > UNSIGNED(seuil) ELSE '0';
    
END Behavior;