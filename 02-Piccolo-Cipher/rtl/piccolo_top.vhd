library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.first_round_pkg.all;       -- wk_rk_array (0..3) of 16-bit
use work.iterative_round_pkg.all;   -- rk_array (IMPORTANT: should be wide enough for 2*i indexing)

entity piccolo_top is
  port(
    clk          : in  std_logic;
    rst          : in  std_logic;

    start        : in  std_logic;

    -- 0: Piccolo-80 (25 rounds), 1: Piccolo-128 (31 rounds)
    key_mode     : in  std_logic;

    -- Serial inputs (16-bit per cycle, during LOADING)
    key_in16     : in  std_logic_vector(15 downto 0);
    data_in16    : in  std_logic_vector(15 downto 0);
    decrypt      : in std_logic;

    -- Serial ciphertext output (16-bit per cycle)
    cipher_out16 : out std_logic_vector(15 downto 0);
    

    done         : out std_logic
  );
end entity;

architecture rtl of piccolo_top is

  ------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------
  component FSM is
    port(
      clk      : in  std_logic;
      rst      : in  std_logic;
      start    : in  std_logic;
      key_mode : in  std_logic;

      key_in16  : in  std_logic_vector(15 downto 0);
      data_in16 : in  std_logic_vector(15 downto 0);
      decrypt   : in std_logic;

      key80_out   : out std_logic_vector(79 downto 0);
      key128_out  : out std_logic_vector(127 downto 0);
      data64_out  : out std_logic_vector(63 downto 0);

      loading_done : out std_logic;
      encrypt_en   : out std_logic;
      done         : out std_logic;

      r_count      : out unsigned(4 downto 0);
      rk_swap      : out std_logic;

      i_mod5       : out std_logic_vector(2 downto 0);
      con_even     : out std_logic_vector(15 downto 0);
      con_odd      : out std_logic_vector(15 downto 0);

      ip2_mod8     : out std_logic_vector(2 downto 0);
      ip3_mod8     : out std_logic_vector(2 downto 0);
      con_i        : out std_logic_vector(15 downto 0);
      con_ip1      : out std_logic_vector(15 downto 0)
    );
  end component;

  component key_scheduler_80 is
    port(
      clk      : in  std_logic;
      rst      : in  std_logic;

      key80    : in  std_logic_vector(79 downto 0);
      load_key : in  std_logic;

      con_even : in  std_logic_vector(15 downto 0);
      con_odd  : in  std_logic_vector(15 downto 0);
      i_mod5   : in  std_logic_vector(2 downto 0);
      decrypt  : in std_logic;
      rk_swap  : in std_logic;

      wk0      : out std_logic_vector(15 downto 0);
      wk1      : out std_logic_vector(15 downto 0);
      wk2      : out std_logic_vector(15 downto 0);
      wk3      : out std_logic_vector(15 downto 0);

      rk_even  : out std_logic_vector(15 downto 0);
      rk_odd   : out std_logic_vector(15 downto 0)
    );
  end component;

  component key_scheduler_128 is
    port(
      clk      : in  std_logic;
      rst      : in  std_logic;

      key128   : in  std_logic_vector(127 downto 0);
      load_key : in  std_logic;
      decrypt  : in  std_logic;
      rk_swap  : in std_logic;
      r_cnt    : in  unsigned(4 downto 0);

      ip2_mod8 : in  std_logic_vector(2 downto 0);
      ip3_mod8 : in  std_logic_vector(2 downto 0);

      con_i    : in  std_logic_vector(15 downto 0);
      con_ip1  : in  std_logic_vector(15 downto 0);
      encrypt_en : in std_logic;
      
      --rk_swap  : in std_logic;

      wk0      : out std_logic_vector(15 downto 0);
      wk1      : out std_logic_vector(15 downto 0);
      wk2      : out std_logic_vector(15 downto 0);
      wk3      : out std_logic_vector(15 downto 0);

      rk_i     : out std_logic_vector(15 downto 0);
      rk_ip1   : out std_logic_vector(15 downto 0)
    );
  end component;

  component first_round is
    port(
      clk        : in  std_logic;
      reset      : in  std_logic;
      plain_text : in  std_logic_vector(63 downto 0);
      init_keys  : in  wk_rk_array;
      encrypt_en : in  std_logic;
      r_cnt      : in  unsigned(4 downto 0);
      X_after    : out std_logic_vector(63 downto 0)
    );
  end component;

  component iterative_round is
    port(
      clk        : in  std_logic;
      reset      : in  std_logic;
      X_in       : in  std_logic_vector(63 downto 0);
      rk_words   : in  rk_array;
      encrypt_en : in  std_logic;
      key_mode   : in  std_logic;
      r_cnt      : in  unsigned (4 downto 0);
      X_after    : out std_logic_vector(63 downto 0)
    );
  end component;

  component last_round is
    port(
      clk        : in  std_logic;
      reset      : in  std_logic;
      X_in       : in  std_logic_vector(63 downto 0);
      final_keys : in  wk_rk_array;
      encrypt_en : in  std_logic;
      r_cnt      : in  unsigned(4 downto 0);
      key_mode   : in  std_logic;
      en_last    : out std_logic;
      Y          : out std_logic_vector(63 downto 0)
    );
  end component;

 
--?? 14 ???????? ??? FSM port-map

  signal key80_out_s            : std_logic_vector(79 downto 0)  := (others => '0');
  signal key128_out_s           : std_logic_vector(127 downto 0) := (others => '0');
  signal data64_out_s           : std_logic_vector(63 downto 0)  := (others => '0');
  signal loading_done_s         : std_logic;
  signal encrypt_en_s           : std_logic;
  signal done_s                 : std_logic;
  signal r_cnt                  : unsigned(4 downto 0); 
  signal i_mod5_s               : std_logic_vector(2 downto 0);
  signal con_even_s, con_odd_s  : std_logic_vector(15 downto 0);
  signal ip2_mod8_s, ip3_mod8_s : std_logic_vector(2 downto 0);
  signal con_i_s, con_ip1_s     : std_logic_vector(15 downto 0);
  

  
  signal rk80_even_s, rk80_odd_s : std_logic_vector(15 downto 0);
  --rsignal rk128_even_s,rk128_odd_s : std_logic_vector(15 downto 0);

    
   --whitening keys array for first and last round

  signal wk80_0, wk80_1, wk80_2, wk80_3 : std_logic_vector(15 downto 0);
  signal first_keys_s : wk_rk_array; 
  signal final_keys_s : wk_rk_array;


  
  signal wk128_0, wk128_1, wk128_2, wk128_3 : std_logic_vector(15 downto 0);
  signal rk128_i_s, rk128_ip1_s             : std_logic_vector(15 downto 0);  


  ------------------------------------------------------------------------------
  -- Round enables
  ------------------------------------------------------------------------------
    signal rounds_max : unsigned(4 downto 0) := "00000" ;
--  signal en_first   : std_logic  := '0' ;
--  signal en_iter    : std_logic  := '0' ;
    signal en_last_d  : std_logic  := '0' ;
    signal rk_swap_s  : std_logic  := '0' ;
  

 

  ------------------------------------------------------------------------------
  -- Datapath chain: first -> iterative -> final
  ------------------------------------------------------------------------------
  signal x_first_s : std_logic_vector(63 downto 0);
  signal x_iter_s  : std_logic_vector(63 downto 0);
  signal x_iter_in : std_logic_vector(63 downto 0);
  signal x_last_s : std_logic_vector(63 downto 0);

  signal rk_words_s : rk_array;

  ------------------------------------------------------------------------------
  -- Serializer regs
  ------------------------------------------------------------------------------
  signal cipher_reg   : std_logic_vector(63 downto 0) := (others => '0');
  signal ser_cnt      : unsigned(2 downto 0) := (others => '0');
  
begin

  ------------------------------------------------------------------------------
  -- FSM
  ------------------------------------------------------------------------------
 U_FSM : FSM
  port map(
    clk          => clk,
    rst          => rst,
    start        => start,
    key_mode     => key_mode,

    key_in16     => key_in16,
    data_in16    => data_in16,
    decrypt      => decrypt,
    key80_out    => key80_out_s,
    key128_out   => key128_out_s,
    data64_out   => data64_out_s,

    loading_done => loading_done_s,
    encrypt_en   => encrypt_en_s,
    done         => done_s,
    

    r_count     =>  r_cnt,
    rk_swap     =>  rk_swap_s,

    i_mod5       => i_mod5_s,
    con_even     => con_even_s,
    con_odd      => con_odd_s,

    ip2_mod8     => ip2_mod8_s,
    ip3_mod8     => ip3_mod8_s,
    con_i        => con_i_s,
    con_ip1      => con_ip1_s
  );

    --? ?????? done ??? Piccolo_top ??? ??? ?????????? ???? ??? FSM ?????? done
    done <= done_s;

  
  U_KS128 : key_scheduler_128
    port map(
      clk      => clk,
      rst      => rst,

      key128   => key128_out_s,
      load_key => loading_done_s,
      decrypt  => decrypt,
      rk_swap   => rk_swap_s,
      r_cnt    => r_cnt,

      ip2_mod8 => ip2_mod8_s,
      ip3_mod8 => ip3_mod8_s,

      con_i    => con_i_s,
      con_ip1  => con_ip1_s,
      encrypt_en => encrypt_en_s,
     
      --rk_swap   => rk_swap_s,

      wk0      => wk128_0,
      wk1      => wk128_1,
      wk2      => wk128_2,
      wk3      => wk128_3,

      rk_i     => rk128_i_s,
      rk_ip1   => rk128_ip1_s
    );

  U_KS80 : key_scheduler_80
    port map(
      clk      => clk,
      rst      => rst,

      key80    => key80_out_s,
      load_key => loading_done_s,
      i_mod5  =>  i_mod5_s,
      decrypt =>  decrypt,
      rk_swap =>  rk_swap_s,

      con_even => con_even_s,
      con_odd  => con_odd_s,

      wk0      => wk80_0,
      wk1      => wk80_1,
      wk2      => wk80_2,
      wk3      => wk80_3,

      rk_even  => rk80_even_s,
      rk_odd   => rk80_odd_s
    );

 
  ------------------------------------------------------------------------------


  ------------------------------------------------------------------------------
  -- 1) FIRST STAGE: first_round
  ------------------------------------------------------------------------------
  U_FIRST : first_round
    port map(
      clk        => clk,
      reset      => rst,
      plain_text => data64_out_s,
      init_keys  => first_keys_s,
      encrypt_en => encrypt_en_s ,
      r_cnt      => r_cnt,
      X_after    => x_first_s
    );

  U_FINAL : last_round
    port map(
      clk        => clk,
      reset      => rst,
      X_in       => x_iter_in,
      final_keys => final_keys_s,
      encrypt_en => encrypt_en_s,  
      r_cnt    => r_cnt,
      key_mode   => key_mode,
      en_last    => en_last_d,
      Y          => x_last_s
     
    );

  U_ITER : iterative_round
    port map(
      clk        => clk,
      reset      => rst,
      X_in       => x_iter_in,
      rk_words   => rk_words_s,
      encrypt_en => encrypt_en_s ,
      key_mode   => key_mode,
      r_cnt      => r_cnt,
      X_after    => x_iter_s
    );

 
 --  first_round 
  -- first_round: (WK0, WK1, RK0, RK1)
  first_keys_s(0) <= wk80_0 when key_mode = '0' else wk128_0;
  first_keys_s(1) <= wk80_1 when key_mode = '0' else wk128_1;
  first_keys_s(2) <= rk80_even_s when key_mode ='0' else rk128_i_s;                       
  first_keys_s(3) <= rk80_odd_s when key_mode =  '0' else rk128_ip1_s;

  -- final_round: (WK2, WK3, RK_r, RK_r+1)
  final_keys_s(0) <= wk80_2 when key_mode = '0' else wk128_2;
  final_keys_s(1) <= wk80_3 when key_mode = '0' else wk128_3;
  final_keys_s(2) <= rk80_even_s when key_mode = '0' else rk128_i_s;
  final_keys_s(3) <= rk80_odd_s  when key_mode = '0'  else rk128_ip1_s;
  
  rk_words_s(0)   <=  rk80_even_s   when key_mode ='0'  else  rk128_i_s; 
  rk_words_s(1)   <=  rk80_odd_s    when key_mode ='0'  else  rk128_ip1_s;
 
  x_iter_in <= x_first_s when r_cnt = 1 else x_iter_s;


  ----------------------------------------------------------------------------
  -- Serializer (unchanged from your file)
 process(clk)
begin
  if rising_edge(clk) then
    if rst='1' then
      ser_cnt      <= (others => '0');
      cipher_reg   <= (others => '0');
      cipher_out16 <= (others => '0');

    
    elsif en_last_d = '1' then
      cipher_reg <= x_last_s;
      ser_cnt    <= "001";  

      cipher_out16 <= x_last_s(63 downto 48);

    
    elsif ser_cnt /= "000" then

      case ser_cnt is
        when "001" => cipher_out16 <= cipher_reg(47 downto 32);
        when "010" => cipher_out16 <= cipher_reg(31 downto 16);
        when "011" => cipher_out16 <= cipher_reg(15 downto 0);
        when others => cipher_out16 <= (others => '0');
      end case;

      if ser_cnt = "0011" then
        ser_cnt <= (others => '0'); 
      else
        ser_cnt <= ser_cnt + 1;
      end if;

    end if;
  end if;
end process;

end architecture rtl;
